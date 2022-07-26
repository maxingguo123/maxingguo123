import sys
import json
import os
import prometheus_client
import prometheus_client.core
import subprocess
import time
import signal
import yaml
import threading
import datetime
import base64


class CollectorDaemon(threading.Thread):
    """
    Daemon that executes collect-sel.py for one node in a loop.
    while True:
        collect-sel.py node01
    """

    MAX_COLLECTION_TIME_SECONDS = 900

    def __init__(self, name, target, user, password):
        threading.Thread.__init__(self)
        self.name = name
        self.target = target
        self.user = base64.b64decode(user.encode('utf-8')).decode()
        self.password = base64.b64decode(password.encode('utf-8')).decode()
        self.last_scrape_ok = 0.0
        self.last_scrape_duration_seconds = 0.0
        self.last_collection_epoch = 0.0
        self.stop_flag = False

    def set_stop_flag(self):
        self.stop_flag = True

    def collect_sel(self):
        try:
            script_directory = os.path.dirname(os.path.realpath(__file__))
            collect_sel_script = os.path.join(script_directory, 'collect-sel.py')
            cmd = [sys.executable, collect_sel_script,
                   "--node", self.name,
                   "--bmc_ip", self.target,
                   "--username", self.user,
                   "--password", self.password]

            proc = subprocess.Popen(cmd)
            try:
                if proc.wait(timeout=CollectorDaemon.MAX_COLLECTION_TIME_SECONDS) == 0:
                    self.last_scrape_ok = 1.0
                else:
                    self.last_scrape_ok = 0.0
            except subprocess.TimeoutExpired:
                print("Timeout for collector: {}, issuing kill command.".format(self.name))
                proc.kill()
                self.last_scrape_ok = 0.0
        except Exception as e:
            self.last_scrape_ok = 0.0
            print(e)

    def run(self):
        while not self.stop_flag:
            t1 = datetime.datetime.now().timestamp()
            self.collect_sel()
            self.last_collection_epoch = t1
            self.last_scrape_duration_seconds = datetime.datetime.now().timestamp() - t1
            collection_interval = os.getenv("COLLECTION_INTERVAL", "30")
            time.sleep(int(collection_interval))


class CollectorManager:
    """
    Class that manages all session processes.
    """

    def __init__(self, configfile, config_format):
        self.configfile = configfile
        self.sessions = {}
        self.config_format = config_format
        signal.signal(signal.SIGINT, self.exit_nicely)
        signal.signal(signal.SIGTERM, self.exit_nicely)

    def _read_config_yaml(self):
        nodes = []
        with open(self.configfile, 'r') as fin:
            cnodes = yaml.load(fin)
            for cnode in cnodes:
                (name, target, username, password) = (
                    cnode['name'], cnode['target'], cnode['username'], cnode['password'])
                nodes.append(self._create_session_key(name, target, username, password))
        return nodes

    def _read_config_prometheus(self):
        nodes = []
        with open(self.configfile, 'r') as fin:
            pobj = json.load(fin)
            for promstring in pobj[0]['targets']:
                (ironic_instance, name, target, username, password) = promstring.split('--')
                nodes.append(self._create_session_key(name, target, username, password))
        return nodes

    def read_config(self):
        if self.config_format == 'prometheus':
            return self._read_config_prometheus()
        elif self.config_format == 'yaml':
            return self._read_config_yaml()

    def _create_session_key(self, name, target, username, password):
        return "{}--{}--{}--{}".format(name, target, username, password)

    def _split_session_key(self, session):
        return session.split("--")

    def start_session(self, configured_session):
        (name, target, username, password) = self._split_session_key(configured_session)
        cd = CollectorDaemon(name, target, username, password)
        cd.start()
        self.sessions[configured_session] = cd

    def exit_nicely(self, signum, frame):
        self.closeall()
        sys.exit(0)

    def retry_broken_sessions(self):
        examined = 0
        retried = 0
        for session in self.sessions:
            examined += 1
            try:
                if not self.sessions[session].is_alive():
                    name = self._split_session_key(session)[0]
                    self.sessions[session].start()
                    retried += 1
            except Exception as e:
                print("Exception caught while retrying session {}, {}".format(session, e))
        print("retry_broken_sessions: scanned {}, restarted {}".format(examined, retried))

    def collect(self):
        """ For Prometheus """
        last_epoch = prometheus_client.core.GaugeMetricFamily('bmc_sel_collection_epoch', 'BMC sel Last Collection Epoch',
                                                     labels=['instance'])
        last_exit_code = prometheus_client.core.GaugeMetricFamily('bmc_sel_collection_ok', 'BMC sel Last Collection Status',
                                                     labels=['instance'])
        last_duration = prometheus_client.core.GaugeMetricFamily('bmc_sel_collection_duration_seconds',
                                                                  'BMC sel Last Collection Duration',
                                                                  labels=['instance'])
        try:
            for session in self.sessions.keys():
                try:
                    session_thread = self.sessions[session]
                    name = session_thread.name
                    last_exit_code.add_metric([name], session_thread.last_scrape_ok)
                    last_epoch.add_metric([name], session_thread.last_collection_epoch)
                    last_duration.add_metric([name], session_thread.last_scrape_duration_seconds)
                except Exception as e:
                    print("Prometheus exporter exception: {}".format(e))
            yield last_exit_code
            yield last_epoch
            yield last_duration
        except Exception as e:
            print("Prometheus exporter main loop exception: {}".format(e))

    def closeall(self):
        for solp in self.sessions:
            self.sessions[solp].set_stop_flag()
        for solp in self.sessions:
            self.sessions[solp].join()

    def synch_status_with_config(self):
        added = 0
        removed = 0
        configured_nodes = self.read_config()
        # add missing
        for configured_session in configured_nodes:
            if configured_session not in self.sessions:
                self.start_session(configured_session)
                print("Adding node: {}".format(configured_session))
                added += 1
        # close sessions removed from config
        toremove = [s for s in self.sessions if s not in configured_nodes]
        for session in toremove:
            (name, target, username, password) = self._split_session_key(session)
            del self.error_counter[name]
            self.sessions[session].close()
            del self.sessions[session]
            removed += 1
            print("Removing node: {}".format(session))
        print("synch_status_with_config: added {}, removed {}".format(added, removed))


if __name__ == '__main__':
    output_directory = os.getenv('OUTPUT_DIRECTORY', '/tmp')
    inventory_file = os.getenv('INVENTORY_FILE', 'prometheus.json')
    config_format = os.getenv('CONFIG_FORMAT', 'prometheus')
    driver_name = os.getenv('DRIVER', 'redfish')

    solpm = CollectorManager(inventory_file, config_format)
    prometheus_client.core.REGISTRY.register(solpm)
    prometheus_client.start_http_server(9666)
    while True:
        try:
            solpm.retry_broken_sessions()
        except Exception as e:
            print("Exception in the main loop retry_broken_sessions: {}".format(e))
        try:
            solpm.synch_status_with_config()
        except Exception as e:
            print("Exception in the main loop synch_status_with_config: {}".format(e))
        time.sleep(10)
