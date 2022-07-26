import copy
from datetime import datetime
from datetime import timezone
import json
from json import JSONEncoder
import requests
import time

# import urllib3 to suppress warning about certificate validation
import urllib3
urllib3.disable_warnings()

from elasticsearch import Elasticsearch

from kubernetes import client, config

UNASSIGNED_POOL_NAME = "Unassigned-K8s-only"

# monkey patch library with broken behavior around missing container names
# causing failures
from kubernetes.client.models.v1_container_image import V1ContainerImage
def names(self, names):
    self._names = names
V1ContainerImage.names = V1ContainerImage.names.setter(names)

class NodeEncoder(JSONEncoder):
    # o - Node
    def default(self, o):
        return self.remove_unknown_timestamps_from_dict(o.__dict__, o.name)

    # o - dict
    def remove_unknown_timestamps_from_dict(self, o, name):
        d = {}
        for key in o.keys():
            if type(o[key]) == dict:
                d[key] = self.remove_unknown_timestamps_from_dict(copy.deepcopy(o[key]), name)
            elif o[key] != "unknown":
                # some keys from clusterscope contain spaces, replace with "_"
                d[key.replace(" ", "_")] = o[key]
            elif key == "location":
                # keep unknown if location
                d[key] = o[key]
        return d


class Node:
    def __init__(self, name, pool, location, time_str):
        self.name = name
        self.pool = pool
        self.location = location
        self.timestamp = time_str
        self.status = "MissingFromK8s"   # Missing or Present
        self.k8s = {}
        self.clusterscope = {}
        self.poolinfo = {}

        self._parse_pool_name(pool)

    def _parse_pool_name(self, name):
        # expected name format:
        #   CPU_STEPPING_ASSIGNTO_STATE_SUBCLUSTERNAME_IDENTIFIER
        cpu_index = name.find("_")
        if cpu_index > 0:
            self.poolinfo["cpu"] = name[:cpu_index]
            name = name[cpu_index+1:]
        stepping_index = name.find("_")
        if stepping_index > 0:
            self.poolinfo["stepping"] = name[:stepping_index]
            name = name[stepping_index+1:]
        assignto_index = name.find("_")
        if assignto_index > 0:
            self.poolinfo["assignto"] = name[:assignto_index]
            name = name[assignto_index+1:]
        state_index = name.find("_")
        if state_index > 0:
            self.poolinfo["state"] = name[:state_index]
            name = name[state_index+1:]
        subcluster_index = name.find("_")
        if subcluster_index > 0:
            self.poolinfo["subcluster"] = name[:subcluster_index]
            name = name[subcluster_index+1:]
        self.poolinfo["ID"] = name

    def __repr__(self):
        return self.name + " " + self.status


class Pool:
    def __init__(self, name, location):
        self.name = name
        self.location = location
        self.nodes = []

    def _set_nodes(self, node_list, time_str):
        for node in node_list:
            self.nodes.append(Node(node, self.name, self.location, time_str))
        print("INFO Pool: {} has {} nodes".format(self.name, len(self.nodes)))

    def add_node(self, name):
        node = Node(name, self.name, self.location, self._elastictime())
        self.nodes.append(node)
        return node

    def _elastictime(self):
        # get elasticsearch formatted time
        now = datetime.now()
        time_str = now.strftime("%Y-%m-%dT%H:%M:%S.%f")
        time_str = time_str[:-3]
        time_str += "Z"
        return time_str

    def get_nodes(self):
        response = requests.get("{}/api/get_nodes_in_pool_for_location?pool={}&location={}".format(CLUSTER_API_URL, self.name, self.location))
        if response.status_code == 200:
            json_data = response.json()
            self._set_nodes(json_data, self._elastictime())
        else:
            utc = get_utc_time()
            print(utc, " ERROR get_nodes_in_pools request failed: status_code: {}, {}".format(response.status_code, response.reason))

    def __repr__(self):
        return self.name


class CmConfig:
    def __init__(self, json_obj):
        global CLUSTER_API_URL
        self.es_cacert = "/elastic-cert"
        self.locations = json_obj.get("locations", [])
        self.es_index = json_obj.get("es_index", "")
        self.es_host = json_obj.get("es_host", "")
        self.es_user = json_obj.get("es_user", "")
        self.es_pass = json_obj.get("es_pass", "")
        self.es_use_ssl = json_obj.get("es_use_ssl", "")
        self.interval = json_obj.get("interval", 180)
        CLUSTER_API_URL = json_obj.get("api_url", "")

def get_utc_time():
    return datetime.now(timezone.utc)

def read_config_map():
    with open('/etc/clusterhealth/config.json', 'r') as configfile:
        data = configfile.read()
    obj = json.loads(data)
    conf = CmConfig(obj)
    return conf

def get_pools(locations):
    pools = []
    response = requests.get("{}/api/pools".format(CLUSTER_API_URL))
    if response.status_code == 200:
        json_data = response.json()
        for key in json_data.keys():
            for location in locations:
                if location in json_data[key]["locations"]:
                    pools.append(Pool(key, location))
    else:
        utc = get_utc_time()
        print(utc, " ERROR get_pools request failed: status_code: {}, {}".format(response.status_code, response.reason))
    return pools

def get_nodes_in_pools(pools):
    for pool in pools:
        pool.get_nodes()
        name_str = ""
        node_dir = {}
        i = 0
        # build a hash of nodes
        for node in pool.nodes:
            name_str = "&name=" + node.name   # build query string for names
            node_dir[node.name] = i
            i += 1

            response = requests.get("{}/api/node/metadata?location={}{}".format(CLUSTER_API_URL, pool.location, name_str))
            if response.status_code == 200:
                json_data = copy.deepcopy(response.json())
                # API can return list or single instance
                if type(json_data) == list:
                    # handle list
                    for node_data in json_data:
                        if type(node_data) == dict:
                            name = node_data["name"]
                            index = node_dir[name]
                            if index >= 0:
                                pool.nodes[index].clusterscope = node_data
                            else:
                                print("INFO Expected node: {} not found in node.dir".format(name))
                        else:
                            print("INFO Expected node metadata not found in cluster-scope")
                elif type(json_data) == type(None):
                    print("INFO Expected node: no metadata found for nodes in pool {}".format(pool.name))
                else:
                    # handle single instance
                    name = json_data["name"]
                    index = node_dir[name]
                    if index >= 0:
                        pool.nodes[index].clusterscope = json_data
                    else:
                        print("INFO Expected node: {} not found in node.dir".format(name))
            else:
                utc = get_utc_time()
                print(utc, " ERROR get metadata request failed: status_code: {}, {}, name {}".format(response.status_code, response.reason, node.name))

def to_elastic_time(dt):
    time_str = dt.strftime("%Y-%m-%dT%H:%M:%S.%f")
    time_str = time_str[:-3]
    time_str += "Z"
    return time_str

def add_k8s_node_data_to_node(node, rnode):
    node.k8s["node_info"] = {}
    node.k8s["node_info"]["architecture"] = rnode.status.node_info._architecture
    node.k8s["node_info"]["bootID"] = rnode.status.node_info._boot_id
    node.k8s["node_info"]["containerRuntimeVersion"] = rnode.status.node_info._container_runtime_version
    node.k8s["node_info"]["kernelVersion"] = rnode.status.node_info._kernel_version
    node.k8s["node_info"]["kubeProxyVersion"] = rnode.status.node_info._kube_proxy_version
    node.k8s["node_info"]["kubeletVersion"] = rnode.status.node_info._kubelet_version
    node.k8s["node_info"]["machineID"] = rnode.status.node_info._machine_id
    node.k8s["node_info"]["operatingSystem"] = rnode.status.node_info._operating_system
    node.k8s["node_info"]["osImage"] = rnode.status.node_info._os_image
    node.k8s["node_info"]["systemUUID"] = rnode.status.node_info._system_uuid
    for address in rnode.status.addresses:
        if address.type == "InternalIP":
            node.k8s["IP"] = address.address
    if rnode.status.capacity.get("cpu", None):
        node.k8s["cpu"] = int(rnode.status.capacity["cpu"])
    if rnode.status.capacity.get("ephemeral-storage", None):
        eph_stor = float(rnode.status.capacity["ephemeral-storage"][0:-2]) / (1024.0 * 1024.0)
        node.k8s["ephemeral_storage"] = float('{:.2f}'.format(eph_stor))
    if rnode.status.capacity.get("memory", None):
        mem = float(rnode.status.capacity["memory"][0:-2]) / (1024.0 * 1024.0)
        node.k8s["memory"] = float('{:.2f}'.format(mem))
    for condition in rnode.status.conditions:
        if condition.type == "DiskPressure":
            node.k8s["disk_pressure"] = condition.status
            node.k8s["disk_pressure_reason"] = condition.reason
            node.k8s["disk_pressure_message"] = condition.message
            node.k8s["disk_pressure_last_heartbeat"] = to_elastic_time(condition.last_heartbeat_time)
            node.k8s["disk_pressure_last_transition"] = to_elastic_time(condition.last_transition_time)
        if condition.type == "MemoryPressure":
            node.k8s["memory_pressure"] = condition.status
            node.k8s["memory_pressure_reason"] = condition.reason
            node.k8s["memory_pressure_message"] = condition.message
            node.k8s["memory_pressure_last_heartbeat"] = to_elastic_time(condition.last_heartbeat_time)
            node.k8s["memory_pressure_last_transition"] = to_elastic_time(condition.last_transition_time)
        if condition.type == "PIDPressure":
            node.k8s["pid_pressure"] = condition.status
            node.k8s["pid_pressure_reason"] = condition.reason
            node.k8s["pid_pressure_message"] = condition.message
            node.k8s["pid_pressure_last_heartbeat"] = to_elastic_time(condition.last_heartbeat_time)
            node.k8s["pid_pressure_last_transition"] = to_elastic_time(condition.last_transition_time)
        if condition.type == "Ready":
            node.status = "Ready" if condition.status == "True" else "NotReady"
            node.k8s["kubelet_ready"] = condition.status
            node.k8s["kubelet_ready_reason"] = condition.reason
            node.k8s["kubelet_ready_message"] = condition.message
            node.k8s["kubelet_ready_last_heartbeat"] = to_elastic_time(condition.last_heartbeat_time)
            node.k8s["kubelet_ready_last_transition"] = to_elastic_time(condition.last_transition_time)
    # labels are too noisy, taking out for now
    #node.k8s["labels"] = rnode.metadata.labels
    node.k8s["spec"] = {}
    node.k8s["spec"]["podCIDR"] = rnode.spec._pod_cidr
    node.k8s["spec"]["podCIDRs"] = rnode.spec._pod_cid_rs
    if rnode.spec.taints != None:
        node.k8s["spec"]["taints"] = []
        for taint in rnode.spec.taints:
            t = {}
            t["key"] = taint.key
            t["effect"] = taint.effect
            node.k8s["spec"]["taints"].append(t)

def get_k8s_node_status(pools):
    node_map = {}
    config.load_incluster_config()
    v1 = client.CoreV1Api()

    # hash so non-n^2 look ups
    ret = v1.list_node(watch=False)
    i = 0
    for node in ret.items:
        node_map[node.metadata.name] = i
        i += 1
    print("INFO k8s nodes found: {}".format(len(node_map)))
    seen_nodes = [False] * len(node_map)

    for pool in pools:
        if len(pool.nodes) > 0:
            for node in pool.nodes:
                index = node_map.get(node.name, -1)
                if index >= 0:
                    seen_nodes[index] = True
                    rnode = ret.items[index]
                    add_k8s_node_data_to_node(node, rnode)
                else:
                    print("INFO Expected node: {} not found in cluster".format(node.name))
        else:
            print("INFO Pool: {} contains 0 nodes found in cluster".format(pool.name))

    # find all the unassigned and zombie nodes and add to UNASSIGNED_POOL_NAME pool
    if False in seen_nodes:
        pool = Pool(UNASSIGNED_POOL_NAME, "unknown")
        pools.append(pool)

        for key in node_map.keys():
            index = node_map.get(key, -1)
            if index >= 0:
                if seen_nodes[index] == False:
                    rnode = ret.items[index]
                    node = pool.add_node(rnode.metadata.name)
                    add_k8s_node_data_to_node(node, rnode)

def publish_health(pools, conf):
    if conf.es_use_ssl == True:
        # for Opus like cluster with https and user and password
        es = Elasticsearch(
            [conf.es_host],
            http_auth=(conf.es_user, conf.es_pass),
            use_ssl=conf.es_use_ssl,
            verify_certs=False,
            ca_certs=conf.es_cacert,
            timeout=30,
            max_retries=5,
            retry_on_timeout=True
        )
    else:
        # for ICX-1 type clusters with http and no auth
        es = Elasticsearch(
            [conf.es_host],
            use_ssl=conf.es_use_ssl,
            verify_certs=False,
            timeout=30,
            max_retries=5,
            retry_on_timeout=True
        )

    for pool in pools:
        for node in pool.nodes:
            doc = NodeEncoder().encode(node)
            try:
                es.index(index=conf.es_index, body=doc)
            except Exception as err:
                utc = get_utc_time()
                print(utc, " ERROR Elasticsearch index(): ", err)

def watch_cluster_health():
    while True:
        try:
            utc = get_utc_time()
            print(utc, " INFO Collecting status")
            conf = read_config_map()
            pools = get_pools(conf.locations)
            get_nodes_in_pools(pools)

            get_k8s_node_status(pools)
            publish_health(pools, conf)
            time.sleep(conf.interval)
        except Exception as err:
            utc = get_utc_time()
            print(utc, " ERROR unhandled exception: ", err)

if __name__ == "__main__":
    watch_cluster_health()
