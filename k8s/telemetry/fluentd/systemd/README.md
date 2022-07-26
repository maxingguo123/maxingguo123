# Installation of fluentd systemd service

## Prerequisites:

* Requires docker to be installed

## Installation

* Clone the cluster-infra repository
  ```bash
  $ git clone https://gitlab.devtools.intel.com/sandstone/cluster-infra
  ```

* Change directory to fluentd
  ```bash
  $ cd cluster-infra/k8s/telemetry/fluentd/systemd/
  ```

* Deploy fluentd

Setup env vars

```bash
export KAFKA=~/latest-cluster-infra/cluster-infra/k8s/telemetry/kafka/out/whitley/cp-helm-charts/charts/cp-kafka/endpoints.yaml
export CLUSTER=whitley
```
  
Reset test logs
```bash
CONFIG=reset-$CLUSTER sudo -E ./setup.sh install
```

VMware test logs (supported only on whitley). 
```bash
CONFIG=vmware-$CLUSTER ./setup.sh install
```
VR-margin execution log collector is running on ive-infra01
```bash
CONFIG=vr-margin-$CLUSTER ./setup.sh install
```

* Verify if the services are running
    
    ```bash
    sudo systemctl status atscale.reset-test.fluentd.service
    * atscale.reset-test.fluentd.service - Atscale Fluentd Service: reset-test
       Loaded: loaded (/etc/systemd/system/atscale.reset-test.fluentd.service; enabled; vendor preset: disabled)
       Active: active (running) since Mon 2020-12-14 21:38:40 UTC; 1 day 2h ago
     Main PID: 8869 (docker)
        Tasks: 18
       Memory: 35.2M
       CGroup: /system.slice/atscale.reset-test.fluentd.service
               └─8869 /usr/bin/docker run --name atscale.reset-test.fluentd.service --entrypoint=/run.sh -v /var/log/reset_tests:/var/log/reset_tests:rw -v /etc/atscale/fluentd/reset-test:/etc/fluent/config.d:...
   
    sudo systemctl status atscale.vmware-test.fluentd.service
    * atscale.vmware-test.fluentd.service - Atscale Fluentd Service: vmware-test
       Loaded: loaded (/etc/systemd/system/atscale.vmware-test.fluentd.service; enabled; vendor preset: disabled)
       Active: active (running) since Mon 2020-12-14 21:38:59 UTC; 1 day 2h ago
     Main PID: 9469 (docker)
        Tasks: 18
       Memory: 35.2M
       CGroup: /system.slice/atscale.vmware-test.fluentd.service
               └─9469 /usr/bin/docker run --name atscale.vmware-test.fluentd.service --entrypoint=/run.sh -v /var/local/common/vmware/systemlogs:/var/local/common/vmware/systemlogs:rw -v /etc/atscale/fluentd/v...
    ```


## Uninstallation

* Uninstall fluentd

Setup env vars

```bash
export KAFKA=~/latest-cluster-infra/cluster-infra/k8s/telemetry/kafka/out/whitley/cp-helm-charts/charts/cp-kafka/endpoints.yaml
export CLUSTER=whitley
```

- Reset logs

```bash
CONFIG=reset-$CLUSTER sudo -E ./setup.sh teardown
```
    
- VMware logs (supported only on whitley at the time of documentation). 

```bash
CONFIG=vmware-$CLUSTER sudo -E ./setup.sh teardown
```

## Checking logs
  
Check service logs as follows
```bash
docker logs -f atscale.reset-test.fluentd.service 
2020-12-14 21:38:41 +0000 [info]: brokers has been set: ["10.219.22.133:31090"]
2020-12-14 21:38:41 +0000 [warn]: default_topic is set. Fluentd's event tag is not used for topic
2020-12-14 21:38:41 +0000 [warn]: define <match fluent.**> to capture fluentd logs in top level is deprecated. Use <label @FLUENT_LOG> instead
2020-12-14 21:38:41 +0000 [info]: initialized kafka producer: fluentd
2020-12-14 21:39:14 +0000 [info]: New topics added to target list: atscale-other

docker logs -f atscale.vmware-test.fluentd.service  
2020-12-14 21:39:00 +0000 [info]: brokers has been set: ["10.219.22.133:31090"]
2020-12-14 21:39:00 +0000 [warn]: default_topic is set. Fluentd's event tag is not used for topic
2020-12-14 21:39:00 +0000 [warn]: define <match fluent.**> to capture fluentd logs in top level is deprecated. Use <label @FLUENT_LOG> instead
2020-12-14 21:39:00 +0000 [info]: initialized kafka producer: fluentd
```

## NOTES
* This service automatically gets logs from files in the specified directory and send it to kafka. 
* If `extract_metadata` is set to `True`, it assumes the following conventions for the directory structure `<LOG ROOT>/<TEST NAME>/<RUNID>/<HOST>/<LOGFILE>`
> * RUNID can be any alphanumeric string uniquely identifying a particular invocation of the test.
> * The implementation assumes logfile is of the form `<FILENAME>.<EXTENSION>` and period (".") is not used anywhere in test name, runid or host.
* To send logs to target kafka, you need to identify a specific topic that receives the logs. This is telemetry cluster specific and requires setting up pipelines to send data from kafka to elasticsearch. Please contact atscale team to setup pipelines before choosing a topic for the logs.
