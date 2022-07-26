# Installation of cluster-scope systemd service

## Purpose:

When a SUT is removed from the Kubernetes environment, such as being moved into debug, the cluster-scope container is no longer executing on the node. This means that the metadata for the node will become stale over time.  This service will install and execute the same cluster-scope container on the system running under systemd control allowing the metadata to remain in sync.

## Prerequisites:

* Requires containerd to be installed

## Installation

* Clone the cluster-infra repository
  ```bash
  $ git clone https://gitlab.devtools.intel.com/sandstone/cluster-infra
  ```

* Change directory to cluster-scope/systemd
  ```bash
  $ cd cluster-infra/k8s/telemetry/cluster-scope/systemd
  ```

* Deploy cluster-scope
  ```bash
  $ ./setup.sh install
  ```
  

### Environment Variables

The cluster-scope [run.sh](https://gitlab.devtools.intel.com/sandstone/cluster-infra/-/blob/master/k8s/telemetry/cluster-scope/run.sh) script expects certain environment variables to be configured. The sysetmd version of the script generates most of these values and passes them to the container when it starts. There are a couple hard coded values that may require editing in the future  
CLUSTER_METADATA=/hostroot/var/log/atscale/cscope-metadata.ndjson  
and the clusterscope pod information.  
prt-registry.sova.intel.com/cluster-scope:v0.61  


## Uninstallation

Uninstall cluster-scope

```bash
./setup.sh teardown
```

