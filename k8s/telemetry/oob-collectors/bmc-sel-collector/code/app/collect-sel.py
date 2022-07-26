import requests
import argparse
import datetime
import json
import urllib3
import shelve
import os
import signal
import sys
import gzip
if os.getenv('KAFKA_BROKERS'):
    import confluent_kafka

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def abort_on_stop_flag():
    if os.path.exists("/tmp/stop-collector"):
        raise RuntimeError("Abort flag detected - exiting")


class KafkaProducer:

    def __init__(self, kafka_brokers, kafka_topic):
        self.producer = None
        self.brokers = kafka_brokers
        self.topic = kafka_topic

    def _get_producer(self):
        # lazy initialization - initialize on the first message submission attempt
        if not self.producer:
            config = {
                "bootstrap.servers": self.brokers
            }
            self.producer = confluent_kafka.Producer(config)
        return self.producer

    def submit_message(self, message):
        p = self._get_producer()
        p.produce(self.topic, message)
        p.flush()


class Logger:

    def __init__(self, path, node, kafka_brokers, kafka_topic, max_size=1000000000):
        self.node = node
        self.path = path
        self.run_id = int(datetime.datetime.now().timestamp())
        self.counter = 1
        self.kp = None
        if kafka_brokers:
            self.kp = KafkaProducer(kafka_brokers, kafka_topic)
        self.filename = os.path.join(path, "{}.log".format(node))
        if self._needs_rotation(max_size):
            self._rotate()
            self._cleanup()

    def __enter__(self):
        self.fd = open(self.filename, 'a')
        return self

    def __exit__(self, type, value, traceback):
        self.fd.close()

    def _needs_rotation(self, max_size):
        return os.path.exists(self.filename) and os.path.getsize(self.filename) > max_size

    def _rotate(self):
        tnow = int(datetime.datetime.now().timestamp())
        os.rename(self.filename, "{}-{}".format(self.filename, tnow))

    def _cleanup(self):
        logfile = "{}.log".format(self.node)
        sorted_files = sorted([x for x in os.listdir(self.path) if x.startswith(logfile) and x != logfile])
        if sorted_files:
            sorted_files.pop()  # spare latest rotated log file
        for file in sorted_files:
            fullname = os.path.join(self.path, file)
            print("Removing {}".format(fullname))
            os.remove(fullname)

    def log(self, sel_entry):
        logline = sel_entry.dict()
        logline['host'] = self.node
        logline['collection_timestamp'] = int(1000 * datetime.datetime.now().timestamp())
        logline['collection_run_id'] = self.run_id
        logline['collection_counter'] = self.counter
        message = json.dumps(logline)
        if self.kp:
            self.kp.submit_message(message.encode('utf-8'))
        self.fd.write("{}\n".format(message))
        self.counter += 1


class IndexCache():

    def __init__(self, cache_path, node):
        self.db_filename = os.path.join(cache_path, "{}.db".format(node))
        self.last_id = ""
        self.event_count = 0
        self._load_values(node)

    def _load_values(self, node):
        with shelve.open(self.db_filename, flag='cu') as db:
            self.last_id = db.get('last_id', "")
            self.event_count = db.get('event_count', 0)

    def set_fake_id(self):
        self.last_id = "1601038455"
#        self.event_count = 4257

    def close(self):
        with shelve.open(self.db_filename, flag='cu') as db:
            db['last_id'] = self.last_id
            db['event_count'] = self.event_count


class SelEntry():
    """ Converts SEL entry to the format acceptable by Elastic/Logstash
        Maintains backward compatibility with previous generations of collectors.
    """

    def __init__(self, bmc_entry):
        self.entry = self._convert(bmc_entry)
        self.id = bmc_entry['Id']

    def dict(self):
        return self.entry

    def json(self):
        return json.dumps(self.entry)

    def _convert(self, bmc_entry):
        converted = {'event': {}}
        for (key, val) in bmc_entry.items():
            if key in ['@odata.id', '@odata.type']:
                continue
            lowerkey = key.lower()
            if lowerkey == 'created':  # maintain  backward compatibility with previous collectors
                lowerkey = 'time'
            if lowerkey == 'message':  # maintain  backward compatibility with previous collectors
                converted[lowerkey] = val
            else:
                converted['event'][lowerkey] = val
        return converted

    def _bmc_time_to_epoch(self, ts):
        return datetime.datetime.strptime(ts, '%Y-%m-%dT%H:%M:%S%z').timestamp() * 1000


class RedfishSel():

    """
    Collects events using redfish protocol. Design assumptions:
    * event ids are not unique
    * event timestamp are not unique and may reset over time
    * events returned from Redfish are in the order they were generated
    """

    def __init__(self, bmc_ip, username, password, endpoint, debug=""):
        self.baseurl = "https://{}".format(bmc_ip)
        self.credentials = {
            "UserName": username,
            "Password": password
        }
        self.location = ""
        self.endpoint = endpoint
        self.s = requests.Session()
        self.next_link = None
        self.entries = []
        self.entries_count = 0
        self.index_skip = -1
        self.call_counter = 0
        self.debug = debug
        self.raw_pages = []

    def login(self):
        url = self.baseurl + "/redfish/v1/SessionService/Sessions"
        tr = self.s.post(url, json=self.credentials, verify=False)
        tr.raise_for_status()
        self.location = tr.headers['Location']
        self.s.headers.update({'X-Auth-Token': tr.headers['X-Auth-Token']})

    def logout(self):
        url = self.baseurl + self.location
        try:
            self.s.delete(url, verify=False)
        except:
            pass

    def _compute_offset(self, last_event_count):
        """ Redfish returns 1000 events per page, try `last_event_count - 100`
            last_event_count-1 won't work, because does not sort events properly.
            If several events occurred within one second, it would return first event from the last second.
            Not the last one.
         """
        if last_event_count > 100:
            return last_event_count - 100
        else:
            return 0

    def _load_page(self, endpoint_with_offset):
        """ Returns array of loaded entries.
            Saves internal state next_link and entries_count.
        """
        self.call_counter += 1
        #print(endpoint_with_offset)
        url = self.baseurl + endpoint_with_offset
        jr = self.s.get(url, verify=False)
        jr.raise_for_status()
        if self.debug:
            self.raw_pages.append((endpoint_with_offset, jr.text))
        response = json.loads(jr.text)
        self.entries_count = response.get('Members@odata.count', 0)
        self.next_link = response.get('Members@odata.nextLink')
        return response.get('Members', [])

    def _load_first_page(self, initial_offset):
        endpoint_with_offset = "{}?$skip={}".format(self.endpoint, initial_offset)
        return self._load_page(endpoint_with_offset)

    def load_events(self, last_id, last_count):
        initial_offset = self._compute_offset(last_count)
        self.entries = self._load_first_page(initial_offset)
        if initial_offset > 0:
            if not self.locate_last_collected_event(last_id):
                self.entries = self._load_first_page(0)

        # iterate over remaining entries
        while self.next_link is not None:
            members = self._load_page(self.next_link)
            self.entries.extend(members)

    def locate_last_collected_event(self, last_id):
        if self.index_skip >= 0:
            return
        if not last_id:
            self.index_skip = 0
        # search from bottom to top (IDs are not unique)
        last_index = len(self.entries) - 1
        if last_index > 0:
            for idx in range(last_index, 0, -1):
                if self.entries[idx].get('Id') == last_id:
                    self.index_skip = idx + 1
                    return self.index_skip
        return 0

    def get_sel_entries(self, last_id, last_count):
        self.load_events(last_id, last_count)
        self.locate_last_collected_event(last_id)
        for entry in self.entries[self.index_skip:]:
            yield self.entries_count, SelEntry(entry)




if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("--node", help="Node Name")
    parser.add_argument("--bmc_ip", help="BMC IP")
    parser.add_argument("--username", help="BMC Username")
    parser.add_argument("--password", help="BMC Password")
    parser.add_argument("--redfish_endpoint", default='/redfish/v1/Systems/system/LogServices/EventLog/Entries',
                        help='Redfish endpoint for SEL entries')
    log_path = os.getenv('LOG_PATH', '/tmp')
    cache_path = os.getenv('CACHE_PATH', '/tmp')
    kafka_brokers = os.getenv('KAFKA_BROKERS', None)
    kafka_topic = os.getenv('KAFKA_TOPIC', None)
    debug = os.getenv("DEBUG", "")
    args = parser.parse_args()

    rj = RedfishSel(args.bmc_ip, args.username, args.password, args.redfish_endpoint, debug=debug)
    ic = IndexCache(cache_path, args.node)
#    ic.set_fake_id()


    def cleanup(signum, frame):
        rj.logout()
        ic.close()


    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)
    last_event_count = 0
    initial_last_id = ic.last_id
    initial_event_count = ic.event_count
    with Logger(log_path, args.node, kafka_brokers, kafka_topic) as logfile:
        try:
            abort_on_stop_flag()
            rj.login()
            for (entry_count, entry) in rj.get_sel_entries(ic.last_id, ic.event_count):
                logfile.log(entry)
                ic.last_id = entry.id
                ic.event_count = entry_count
            if logfile.counter > 1 and debug:
                raw_filename = os.path.join(log_path, "raw-responses.{}.{}.gz".format(args.node, logfile.run_id))
                with gzip.open(raw_filename, 'wt') as fw:
                    for (endpoint, response) in rj.raw_pages:
                        fw.write("QUERY: {}\n".format(endpoint))
                        fw.write(response)
                        fw.write("\n")


            print(f"{args.node} - [{logfile.run_id}], collected {logfile.counter - 1} events using {rj.call_counter} redfish calls. Cache ({initial_last_id}, {initial_event_count} -> {ic.last_id}, {ic.event_count})")
        except Exception as e:
            print("{} - error - {}".format(args.node, e))
            sys.exit(1)
        finally:
            rj.logout()
            ic.close()
