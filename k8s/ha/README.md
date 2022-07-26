# HA Install 

A high-availability multi-master setup with HAProxy and Keepalived. HA host refers to a host running keepalived and haproxy, NOT a master or worker node.

## Prerequisites

### Determine the HA IP

Determine the IP to be used as the main HA address by keepalived. It should NOT be an existing interface address. In the event the primary keepalived fails, keepalived will move this address to one of the other keepalived hosts.

### Setup Cluster kubeadm.yaml

The Master control plan should be installed with multiple SANs entries to allow access to the k8s API without the HAProxy nodes. Enter IP addresses for each master and HA server as well as the keepalived IP.

```
#kubeadm.yaml for flex example
apiVersion: v1
data:
  ClusterConfiguration: |
    apiServer:
      certSANs:
      - 127.0.0.1
      - 10.45.128.86
      - 10.45.128.87
      - 10.45.128.88
      - 10.45.128.89
      - 10.45.128.90
      - 10.45.128.91
      - 10.45.128.9
      - localhost
```

The kubeadm.yaml should also specify the keepalived IP:

```
apiVersion: v1
data:
  ClusterConfiguration: |
    ...
    controlPlaneEndpoint: 10.45.128.9:6666
```

## Install HAProxy and Keepalived

One each HA host, install haproxy and keepalived.

```
yum install -y keepalived haproxy
```

## Copy Files and Start Services

For the given cluster, copy the corresponding files to each HA host (e.g. copy flex files fromm ./flex directory) as described below.

```
# on a001telehaproxy001 host
cp cluster-infra/k8s/ha/flex/a001telehaproxy001/keepalived.conf /etc/keepalived/keepalived.conf
cp cluster-infra/k8s/ha/flex/check_haproxy.sh /etc/keepalived/check_haproxy.sh
cp cluster-infra/k8s/ha/flex/a001telehaproxy001/haproxy.cfg /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy keepalived
```

Repeat the above steps for each remaining HA host.
