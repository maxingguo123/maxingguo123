#!/usr/bin/python3

import sys
import json
import os
import prometheus_client
import prometheus_client.core
import time
import signal
import yaml
import socket
import re

from drivers import SolSessionManager


class SolProcessGroupManager:
    """
    Class that manages all session processes.
    """
    NODES_PER_GROUP=200

    def __init__(self, driver_name, configfile, configformat, output_directory, write_raw_files, nodes_per_pod):
        self.configfile = configfile
        self.output_directory = output_directory
        self.sessions = {}
        self.error_counter = {}
        self.driver_name = driver_name
        self.configformat = configformat
        self.write_raw_files = write_raw_files
        self.nodes_per_pod = nodes_per_pod
        self.group_enum = self._get_pod_enum()
        signal.signal(signal.SIGINT, self.exit_nicely)
        signal.signal(signal.SIGTERM, self.exit_nicely)

    # staefulset pod id - to determine which config part to manager
    def _get_pod_enum(self):
        hostname = socket.gethostname()
        rg = re.match(r".*-([0-9]+)$", hostname)
        if rg:
            return int(rg.group(1))
        else:
            return -1

    def _slice(self, nodes):
        if self.group_enum == -1:
            print("Ignoring config group - it is not a pod from a statefulset")
            return nodes
        print("Config group: {}".format(self.group_enum))
        gstart = self.nodes_per_pod*self.group_enum
        gend = self.nodes_per_pod*(self.group_enum+1)
        # a=[0,1,2,3,4,5,6,7,8,9,10]
        # NODES_PER_GROUP=10
        # iteration=0, gstart = 0, gend=10, len(a)==11
        # iteration=1, gstart = 10, gend=20, len(a)==11
        if gstart > len(nodes)-1:
            return []
        if gend > len(nodes)-1:
            return nodes[gstart:]
        else:
            return nodes[gstart:gend]

    def _read_config_yaml(self):
        nodes = []
        with open(self.configfile, 'r') as fin:
            cnodes = yaml.load(fin)
            for cnode in cnodes:
                (name, target, username, password) = (cnode['name'], cnode['target'], cnode['username'], cnode['password'])
                nodes.append(self._create_session_key(name, target, username, password))
        return self._slice(nodes)

    def _read_config_prometheus(self):
        nodes = []
        with open(self.configfile, 'r') as fin:
            pobj = json.load(fin)
            for promstring in pobj[0]['targets']:
                (ironic_instance, name, target, username, password) = promstring.split('--')
                nodes.append(self._create_session_key(name, target, username, password))
        return self._slice(nodes)

    def read_config(self):
        if self.configformat == 'prometheus':
            return self._read_config_prometheus()
        elif self.configformat == 'yaml':
            return self._read_config_yaml()

    def _create_session_key(self, name, target, username, password):
        return "{}--{}--{}--{}".format(name, target, username, password)

    def _split_session_key(self, session):
        return session.split("--")

    def start_session(self, configured_session):
        (name, target, username, password) = self._split_session_key(configured_session)
        self.error_counter[name] = 0.0
        solp = SolSessionManager(name, target, username, password, self.output_directory, self.driver_name, self.write_raw_files)
        solp.start()
        self.sessions[configured_session] = solp

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
                    self.error_counter[name] += 1.0
                    self.sessions[session].start()
                    retried += 1
            except Exception as e:
                print("Exception caught while retrying session {}, {}".format(session, e))
        print("retry_broken_sessions: scanned {}, restarted {}".format(examined, retried))

    def collect(self):
        """ For Prometheus """
        c = prometheus_client.core.CounterMetricFamily('sol_reconnect_counter', 'SOL reconnect counter', labels=['instance'])
        h = prometheus_client.core.GaugeMetricFamily('sol_ok', 'SOL session is established', labels=['instance'])
        try:
            for session in self.sessions:
                value = self.sessions[session].health_ok()
                name = self.sessions[session].name
                h.add_metric([name], value)
            yield h
        except Exception as e:
            print("Exception caught in prometheus collector: {}".format(e))
        try:
            for name in self.error_counter:
                c.add_metric([name], self.error_counter[name])
            yield c
        except Exception as e:
            print("Exception caught in prometheus collector: {}".format(e))

    def closeall(self):
        for solp in self.sessions:
            self.sessions[solp].close()

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
    nodes_per_pod = int(os.getenv('NODES_PER_POD', '500'))
    write_raw_files = 'WRITE_RAW_DEBUG_OUTPUT' in os.environ

    solpm = SolProcessGroupManager(driver_name, inventory_file, config_format, output_directory, write_raw_files, nodes_per_pod)
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
