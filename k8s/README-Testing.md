# Arkose Workflow

## Dashboards

- [Cluster Test Execution Dashboard](https://kibana.gdc.sova.intel.com/app/kibana#/dashboard/9ed6ba20-b4ba-11e9-9f9b-6b0b9ee2cb20?_g=(refreshInterval%3A(pause%3A!t%2Cvalue%3A0)%2Ctime%3A(from%3Anow-24h%2Cmode%3Aquick%2Cto%3Anow)))
  This provides an instantaneous view of the state of the whole cluster. This reports what tests were run and what failure were seen.
- [Cluster Test Raw Telemetry](https://kibana.gdc.sova.intel.com/app/kibana#/discover/8d7c5ea0-b4b1-11e9-9f9b-6b0b9ee2cb20?_g=(filters%3A!()%2CrefreshInterval%3A(pause%3A!f%2Cvalue%3A300000)%2Ctime%3A(from%3Anow-24h%2Cmode%3Aquick%2Cto%3Anow)))
  This gives the raw query in Kibana which is then used to build the dashboards.
- [Cluster Test Failure Raw Telemetry](https://kibana.gdc.sova.intel.com/app/kibana#/discover/1fb90200-b62e-11e9-9f9b-6b0b9ee2cb20?_g=(filters%3A!()%2CrefreshInterval%3A(pause%3A!f%2Cvalue%3A300000)%2Ctime%3A(from%3Anow-24h%2Cmode%3Aquick%2Cto%3Anow)))
  This gives the raw query in elastic that tracks failures.
- [Cluster Summary Hardware Telemetry](https://dashboards.gdc.sova.intel.com/d/Gzqs88DWk/prt-all-nodes-key-metrics?orgId=1&from=now-24h&to=now)
  This gives summary dashboard on hardware level telemetry including CPU Utlization, MCE's, temperature etc on a per node basis.
- [Cluster Node Hardware Dashboard](https://dashboards.gdc.sova.intel.com/d/kixfKBHWk/prt-node-telemetry?orgId=1)
  This gives full detail on hardware level telemetry including CPU Utlization, MCE's, temperature etc on a per node basis.
- [CI status](http://clr-sandstone.jf.intel.com:8080/job/sandstone-build/)
- [CD status](http://clr-sandstone.jf.intel.com:8080/view/Pipelines/)
- [Reference pool status](http://clr-sandstone.jf.intel.com:8080/job/sandstone-val-pool/)
- [Telemetry Repository](https://sv-gitlab.igk.intel.com/k8s-qpool/telemetry)
- [Telemetry Indices](https://wiki.ith.intel.com/display/e2e/Telemetry)
- [Rack 14 Telemetry](http://gmslc5004.zpn.intel.com/clusterscope/r14.html)

## Contacts

- Cluster Management, Cluster Deployment, Containerization, Kubernetes test framework
  - manohar.r.castelino@intel.com
- Workload Definition and test cases
  - james.t.kukunas@intel.com

## Goals

The goal of the test infrastructure is to allows developers to rapidly evolve test content
and deploy it to systems under test. We also wanted to use available opensource tools to
schedule work from multiple developers/teams and share the systems.  We also
wanted the scheduler to be able to schedule work at a fine grained level to
a specific CPU/Node.

## README FIRST

Any project needs to have the following

- Dockerfile
  - Please use the Dockerfile in this repo as an example Dockerfile for constructing your workload container.
- Workload execution wrapper
  - Please refer to the [scripts/run-specific.sh](http://kojiclear.jf.intel.com/cgit/bdx/sandstone/tree/scripts/run-specific.sh) for details on how the workload is executed
    and how success and failure are determined.
- Kubernetes Deployment
  - Please refer to the manifest [k8s/sandstone_run_specific.yaml](http://kojiclear.jf.intel.com/cgit/bdx/sandstone/tree/k8s/sandstone_run_specific.yaml) for sandstone.
    - Note the use of the `readinessProbe` and the `nodeSelector`

The rest of the framework is generic and does not need any changes from workload to workload.
You can use this exact same setup with just sandstone changed to your project name in all the files above.

## Automated CI and CD

This repository has automated CI and CD. Arkose uses Jenkins to perform both CI and CD.
[Jenkins](http://clr-sandstone.jf.intel.com:8080/) is responsible for CI and CD.

Note: This means that users no longer need to perform deployment.  Deployment is now the
responsibility of the CI/CD system.

### Jenkins CI

Jenkins monitors the repository every two minutes for changes. When any change is detected
it builds the code and runs a round of testing. If the code **passes testing** the container
image containing the code is staged to the container repository with the tag jenkins-latest.
The container image is available for use as `prt-registry.sova.intel.com/sandstone:jenkins-latest`.

Note: CI script [ci.sh](http://kojiclear.jf.intel.com/cgit/bdx/sandstone/tree/scripts/ci.sh)

### Jenkins CD

The server running Jenkins is setup to have network connectivity to the control node.
It is also setup with the credentials to control Kubernetes in the cluster.

Jenkins in CD mode picks latest CI stable build (jenkins-latest) and deploys this in the cluster.
Jenkins runs the tests for a total duration of 300 seconds and checks for failure. Jenkins logs the
test results, cleans up the deployment and then starts the process all over again.

As Jenkins in CD mode always picks the last build that passes CI. Hence the cluster will always
be running the lastest stable build produced by the CI system.

The logs from kubernetes are available in Jenkins as well in Elastic.
All other logs are available in Elastic

Note: CD script [jenkins-cluster-cd.sh](http://kojiclear.jf.intel.com/cgit/bdx/sandstone/tree/k8s/jenkins-cluster-cd-specific.sh)

Note: We sometime see CD failures when Jenkins looses network connectivity to the cluster.
There errors can be ignored as they are due to the ssh reverse port forwarding failure from
the control node back to Jenkins.

Note: autossh is used to keep a persistent connection from root@r14s24 to Jenkins

```bash
autossh -f -M 0 -o "ExitOnForwardFailure=yes" -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -f -N -T -R 6443:127.0.0.1:6443 sandstone@clr-sandstone.jf.intel.com
```

## Theory of operation

- All content is built and packaged on the developers machines into
  container images. This allows the content to be tagged and delivered
  to the test nodes in a reproducible manner.

- The containers are built such that the container is expected to exit
  with error, hang or crash (or crash the node) on error.

- The container is expected to create a file `/tmp/testdone` within
  the container if the test completes. (This does not mean there
  is no error when the test executed. That will be detected by the
  framework via Node Problem Detector or log based Telemetry)

- The file `/tmp/testdone` serves as the Kubernetes readiness probe.
  This allows Kubernetes to watch for the creation of this file.
  If this file is created Kubernetes considers this container to be
  `Ready`.

  Typically `Ready` in Kubernetes is used to indicate that a container
  is available to accept work. We however use `Ready` to indicate
  completion of the test.  This allows us to wait for a finite amount of
  time for the tests to complete.

- If the readiness probe does not come back within the time it takes for
  the workload to complete it means that the test has hung.

  In summary
  - If probe does not come back: Test has hung
  - If probe has come back: Test has completed with success or failure
  - We need to gather logs from the telemetry to obtain next level data

## Infrastructure

The current test infrastructure consists of the following

- Developer systems
- A private container registry
- A NAT jump host that is used to access the cluster
- A cluster of test nodes and a control node

```
+-------------+                                                         +----------+
|             |                                                     +-->+Test Node 1
| dev sys     +-------+                                             |   +----------+
|             |       |                                             |
+-------------+       |                                             +--->
                      |    +---------+     +-------+    +--------+  |
                      +--->+registry +---->+ NAT   +--->+control +--+
                      |    |         |     |       |    |        |  |
+--------------+      |    +---------+     +-------+    +--------+  +-->
| dev sys      |      |                                             |
|              +------+                                             |   +-------------+
+--------------+                                                    +-->+Test Node 8  |
                                                                        +-------------+
```

Note: We will need at least one more control node to store telemetry.

### Developer Systems

Each developer is free to use their systems to develop sandstone test content.
Once they are satisfied with the code the developers tag and push their test image
to the container registry.

### Private Container Registry

The container registry is used to stage container images
onto the cluster. This container registry is accessible to
developers to push container images.

The container registry is also accessible to the test cluster to
pull images. The test cluster uses tagged images to run test
content on the test node.

Note: Currently the secure container registry is hosted at `prt-registry.sova.intel.com`.
Longer term we need to use authentication for the registry if we need to secure the test content.

### NAT Jump Host

The NAT Jump host serves to both isolate the test nodes from
the Intel network as well as provide *outbound* network connectivity
from the test nodes and control node to the Intel and external network.

### Control node

Is the node that hosts the Kubernetes control plane. This is the only
node that developers directly interact with on the cluster.
As the test cluster is isolated from the Intel network, developers will
need to log into this node to run their jobs.

The control node is setup to have credentials to control all nodes
on the cluster.

The control node does not run any tests.

The control node gathers telemetry from the cluster and can report put

- Test failures
- Node failures
- Machine checks across the cluster
- Test node telemetry using Node Problem Detector and  fluentd
- Fluentd is setup to send all logs to a centralized elastic that is
  running outside the cluster

Today we take a lock in the control node to ensure no two persons
schedule jobs at the same time. So your job will fail immediately
if there is an active job.

**Note all deployments created should use the same lock file currently defined to be `/tmp/sandstone_cluster_in_use.lock`**

Note: Longer term this will not be needed as the jobs can be dispatched
transparently from developer systems without needed to get on the control
node.

### Test nodes

The test nodes act as worker nodes in the cluster and will run developer
dispatch jobs.

Node Problem Detector actively scan the system for critical events and
flags them as Kubernetes events.

Fluentd gathers logs from the system as well as test runs and feeds them
into an elastic database.

### Node Tagging

 Tests run only on those nodes which are tagged with `testnode: "true"`.
 A node can be dynamically removed from test execution by untagging it.
 This allows us to take out a node that is showing a test failure for triage.

 Nodes can be tagged with any number of tags and jobs can be scheduled
 based on node tags.

- Get the node name `kubectl get nodes`
 -To enable testing on a node `kubectl label nodes <node-name> testnode=true`
 -To disable testing on a node `kubectl label nodes <node-name> testnode-`

## Developer workflow

## Docker pre-req

1) Install docker on your system: sudo apt install docker.io
2) Configure proxies in two steps:
    2a) create a file ~/.docker/config.json with this content:

```bash
{
 "proxies":
 {
   "default":
   {
     "httpProxy": "http://proxy.jf.intel.com:911",
     "httpsProxy": "http://proxy.jf.intel.com:911",
     "noProxy": "*.intel.com"
   }
 }
}
```

    2b) `mkdir /etc/systemd/system/docker.service.d`and create 3 files in that
    dir
        - http-proxy.conf
        - https-proxy.conf
        - proxy.conf
    Contents of each file:

    ```
    [Service]
    Environment="HTTP_PROXY=http://proxy-chain.intel.com:911"
    Environment="HTTPS_PROXY=http://proxy-chain.intel.com:911"
    ```

3) Configure docker to start on boot and manage docker as a [non-root user](https://docs.docker.com/install/linux/linux-postinstall/)

Test if docker can talk to the outside world:

```bash
docker run hello-world
```

If docker is configured correctly, you should see something like this:

```bash
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
1b930d010525: Pull complete
Digest: sha256:6540fc08ee6e6b7b63468dc3317e3303aae178cb8a45ed3123180328bcc1d20f
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
..
```

### Add docker registry

The dev machines need to setup to trust the private registry.
This can be done by adding the following lines to your
`/etc/docker/daemon.json` file.

```bash
"insecure-registries" : ["prt-registry.sova.intel.com"]
```

### Build and tag test content

Developers build the test content and pushes it to the registry.
If no DOCKER_TAG is specified, $(USER)_<git_commit_id> will be used as the tag.
You will see this auto-generated tag on the last line of the make docker output.

```bash
[DOCKER_TAG=mrcastel] make docker
```

Here I am tagging the container image with the tag `mrcastel`.
So the image pushed to the registry will be `prt-registry.sova.intel.com/sandstone:<TAG>`.
This tag will be used in the instructions below.

**Please use your own unique tag when deploying to the cluster.**

A developer can choose to push any number of uniquely tagged images to the registry.

### Run the test locally on your system to ensure it is correct

```bash
docker run prt-registry.sova.intel.com/sandstone:mrcastel
```

If it works on your machine, time it to know the runtime and then go on
to the next step. If not fix your tests locally to prevent false negative.

### Run the tests

To run the test the developer needs to get on the control node via the jumphost.

First ssh into the jumphost using your idsid and password

```bash
ssh idsid@gmslc5006.zpn.intel.com
```

Then ssh into the control node `r14s24`

```bash
ssh r14s24
```

Note: We currently run tests on r14s01-r14s08

Check that no one else is running any tests

```bash
kubectl get po -o wide
kubectl get daemonsets -o wide
```

Both these commands should return empty.

We also take a local lock on the control node to ensure there is no race.
This means that once a job is scheduled and completed no one else can
deploy another job.

Note: This is temporary. Once we have a proper job queuing interface in place
your job will be queued up for execution.

Run your test

```bash
cd sandstone
git pull
DOCKER_TAG=mrcastel TEST_TIMEOUT=3m make deploy
```

This will run the sandstone on all test nodes if it is able to take the lock.

Note: Please choose a timeout that is guaranteed to allow the tests to complete.
If you choose a wrong timeout you can always cleanup and redeploy using

```bash
DOCKER_TAG=mrcastel  make deployclean
```

If sandstone runs successfully to completion on all nodes the command will
return and cleanup after itself and give up the lock.

If sandstone fails or hangs on any node the command will return with failure.
If there is a fail or hang the command will not cleanup so as to allow
us to root cause the failure. **The lock will still be held to ensure that we can triage the failure**

To see what has happened run the following command

```bash
kubectl get po -o wide
```

The nodes on which the test has hung will be marked as not ready.

You can check the logs of the test run using

```bash
kubectl logs <podname>
```

You can also check if there were any issues by checking for any events.

```bash
kubectl get events
kubectl get events --all-namespaces --field-selector reason="Hardware Error"
kubectl get events --all-namespaces --field-selector reason="sandstoneError"
```

Once the failure has been root caused cleanup using

```bash
DOCKER_TAG=mrcastel  make deployclean
```

This will also give up the lock.

Note: In the future the tests will also fail if there is a machine check
observed on any node. The events includes node reboots, kernel panics,
application core dumps etc which are gathered across the cluster.

## Summary

`make deploy` allows the user to choose the amount of timeout for a
test to complete across the cluster. So hitting the timeout is an
indication of failure. The timeout **needs** to be large enough to
ensure that the test **will** completely.

However on hitting the timeout the user does not need to assume that
this is a error. For example for tests that run for infinite time
we can specify very large timeouts and wait loop and looks for
errors by monitoring for error events using `kubectl get events`.

Note: In the future the tests will also exit with error if any node
level error events are detected.

## How was the cluster setup

**This should _NOT_ be performed by anyone besides cluster admins**

**This is documented for completeness for cluster maintainers**
**Please do not do any of these steps, else you will break the cluster**

This is not information for developers, but for people managing the
cluster.

- The cluster is setup to run Clearlinux.

- Time should be synchronized across the cluster.

```bash
mkdir -p /etc/systemd/system

cat > /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=192.168.0.3
FallbackNTP=10.18.116.209
EOF

systemctl enable systemd-timesyncd
systemctl restart systemd-timesyncd
timedatectl timesync-status
```

- The cluster is setup with a custom mcelog service which generates ndjson
  formatted output. (The patch for mcelog is found in this repository).
  This ensures that Kubernetes events container full machine check
  qualification in a single Kubernetes event.

```bash
mkdir -p /etc/systemd/system
mkdir -p /usr/local/bin

cat > /etc/systemd/system/mcelog.service <<EOF
[Unit]
Description=Machine Check Exception Logging Daemon
After=syslog.target

[Service]
ExecStart=/usr/local/bin/mcelog --ignorenodev --daemon --foreground --json
StandardOutput=syslog
SuccessExitStatus=0 15

[Install]
WantedBy=multi-user.target
EOF
```

- On each system set it up to trust our own registry. Also set it up to capture larger single line logs.

```bash
mkdir -p /etc/containerd
cat > /etc/containerd/config.toml <<EOF
[plugins]
  [plugins.cri]
    max_container_log_line_size = 499900
    [plugins.cri.registry]
      [plugins.cri.registry.mirrors]
        [plugins.cri.registry.mirrors."prt-registry.sova.intel.com"]
          endpoint = ["https://prt-registry.sova.intel.com"]
        [plugins.cri.registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
EOF
```

- Setup telemetry gathering on the systems

```bash
http_proxy=http://proxy-us.intel.com:911 https_proxy=$http_proxy pip install ansible
http_proxy=http://proxy-us.intel.com:911 https_proxy=$http_proxy swupd bundle-add git
ansible-pull -U https://sv-gitlab.igk.intel.com/mve-playbooks/rsyslog.git -C master -f
ansible-pull -U https://sv-gitlab.igk.intel.com/mve-playbooks/node-exporter.git -C master -f
```
Note: Provide the node names and ip addresses all the machines to Jakub (jakub.dlugolecki@intel.com)

- On each system we then prime it as follows

```bash
ip route add default via 192.168.1.101
nohup bash -c "while true; do ip route add default via 192.168.1.101; sleep 60; done" &
export http_proxy=http://proxy-us.intel.com:911
export https_proxy=http://proxy-us.intel.com:911
export no_proxy=127.0.0.0/8,localhost,10.0.0.0/8,192.168.0.0/16,192.168.14.0/16,192.168.14.1,192.168.14.2,192.168.14.3,192.168.14.4,192.168.14.5,192.168.14.6,192.168.14.7,192.168.14.8,192.168.14.24,192.168.14.101,192.168.14.102,192.168.14.103,192.168.14.104,192.168.14.105,192.168.14.106,192.168.14.107,192.168.14.108,192.168.14.124,.intel.com
swupd bundle-add cloud-native-basic git
git clone https://github.com/clearlinux/cloud-native-setup
cd cloud-native-setup/clr-k8s-examples/
./setup_system.sh
```

This primes the system to be able to run kubernetes.
Note: If you add more test systems to the cluster their IP addresses need to be added to the list as linux does not handle subnet masks 192.168.14.0/16. Hence each and every system has to be added.
Note: Ideally we should have run a transparent proxy on the NAT gateway. This will make the cluster look like a standard kubernetes deployment.

- On the control node launch the control plane

```bash
cd cloud-native-setup/clr-k8s-examples/
./create_stack.sh init
```

- Join the worker node to the control plane using the creds from the pervious step

```bash
sudo -E kubeadm join ...
```

- On the control node setup networking

```bash
cd cloud-native-setup/clr-k8s-examples/
./create_stack.sh cni
```

- The cluster is setup to use Node Problem Detector to watch each system for *critical events* like MCEs and OOM and Program crashes. It is also setup to capture any kernel events generated by sandstone.

```bash
kubectl apply -f k8s/npd_mce.yaml
```

- Event router will watch for Kubernetes events and capture them in the system logs.

```
kubectl apply -f k8s/eventrouter.yaml
```

### Setting up persistent volumes for local storage provisioning

#### Prepare host for local provisioning

- Copy `k8s/telemetry/create_sparse_vol.sh` to the host machine where PVs need to be created.

-  Run the `create_sparse_vol.sh` script to create a sparse image as follows.

```bash
./create_sparse_vol.sh <NAME> <SIZE>
# SIZE may be (or may be an integer optionally followed by) one of following: KB 1000, K 1024, MB 1000*1000, M 1024*1024, and so on for G, T, P, E, Z, Y.
```

#### Sample PV configuration

Here is a sample list of volumes created for use by prometheus and kafka on whitley cluster. Note that it might change as we test larger clusters.

- Create PVs on three telemetry VMs for Prometheus
```bash
./create_sparse_vol.sh prom-storage 140G
```

- Create PVs on three telemetry VMs for Grafana
```bash
./create_sparse_vol.sh grafana-storage 101M
```
- Create PVs on three telemetry VMs for Kafka and Zookeeper
```bash
./create_sparse_vol.sh kafka 50G
./create_sparse_vol.sh zookeeper-data 4G
./create_sparse_vol.sh zookeeper-log 1G
```

#### Deploy local storage provisioner

- Deploy storage class for local volume provisioning

```bash
kubectl create ns mgmt
kubectl apply -f k8s/telemetry/local-storage.yaml
```

- Deploy controller for dynamic local storage provisioning

```bash
kubectl apply -f k8s/telemetry/local-provisioner.yaml
```

NOTE: Every time we add or remove a persistent volume image, we need to restart the local-provisioner.

#### Deploy Kafka

- Get Kafka helm charts from following location:

   https://github.com/confluentinc/cp-helm-charts.git
   Tag: v5.4.1

- Deploy kafka using the custom yaml file

   helm install -f ../../values.yaml . --name-template  atscale-kafka --namespace monitoring

- Customize fluentd-bridge with kafka and elastic endpoints and deploy.
   TBD: Steps to customize
   OPEN: Should kafka topics be created before deploying fluent?

- Customize fluentd-kafka with kafka endpoints and deploy on worker nodes.


#### Deploy Telemetry stack

- Telemetry is configured on the cluster to monitor the health of the cluster and the health of fluentd.

```bash
kubectl apply -f ./k8s/telemetry/kube-prometheus/manifests/setup/
kubectl apply -f ./k8s/telemetry/kube-prometheus/manifests/
kubectl apply -f ./k8s/telemetry/fluentd-es-monitor.yaml
kubectl apply -f ./k8s/telemetry/fluentd-prom-monitor.yaml
kubectl apply -f ./k8s/telemetry/metrics-api/
```

- The cluster is setup to run Fluentd to gather all container logs as well as critical services log to a centralized elastic. This provides additional visibility into the individual test runs. This uses fluent to scrape the logs from across the cluster and from each individual test run. The logs are fed to elastic and then can be visualized using Kibana.

```bash
    ELASTIC_IP=192.168.0.11
    ELASTIC_PORT=920
    CLUSTER=purley
    USERNAME=default
    bash -x k8s/efk/setup.sh
    kubectl apply -f ./k8s/efk/fluentd-es-configmap-$USERNAME.yaml
    kubectl apply -f ./k8s/efk/fluentd-es-ds-$USERNAME.yaml
```

- Alternatively the configuration variables can be setup in k8s/efk/config/<cluster name>.sh. In such a case we deploy fluentd-es as follows:

```bash
    CLUSTER=whitley
    bash -x k8s/efk/setup.sh
    kubectl apply -f ./k8s/efk/fluentd-es-configmap-$USERNAME.yaml
    kubectl apply -f ./k8s/efk/fluentd-es-ds-$USERNAME.yaml
```

- Configure prometheus to consume fluentd metrics.

```bash
    CLUSTER=purley
    USERNAME=default
    bash -x k8s/telemetry/fluentd/prom/setup.sh
    kubectl apply -f ./k8s/telemetry/fluentd/prom/fluentd-prom-configmap-$USERNAME.yaml
    kubectl apply -f ./k8s/telemetry/fluentd/prom/fluentd-prom-ds-$USERNAME.yaml
```

- Alternatively the configuration variables can be setup in k8s/efk/config/<cluster name>.sh. In such a case we deploy fluentd-es as follows:

```bash
    CLUSTER=whitley
    bash -x k8s/telemetry/fluentd/prom/setup.sh
    kubectl apply -f ./k8s/telemetry/fluentd/prom/fluentd-prom-configmap-$USERNAME.yaml
    kubectl apply -f ./k8s/telemetry/fluentd/prom/fluentd-prom-ds-$USERNAME.yaml
```

- Node manager provides several functions for tracking data and metadata from nodes in the test cluster.

```bash
kubectl apply -f ./k8s/node-manager.yaml
```

### Handling Reboot

The cluster is set up to handle reboot in an **interesting manner**.

- We need to be able to handle network link instability different from a node reboot.
- The machines cannot reach the registry without the default gateway.
- When the link goes down or machine reboots the default gateway is lost, hence a container image cannot be retrieved.
- The default gateway is added back on link reset via the nohup loop above
- On node reboot the nohup loop is lost

Kubernetes by default will automatically rejoin a node on reboot and restart scheduling. We want the node to rejoin the cluster so that the tokens do not expire. But we still want the tests to detect that easily. We also want to be able to triage that node before scheduling jobs back on it.

Using this trick allows the node to rejoin on reboot but in a state where it cannot fetch the test container image.

tl;dr Just run the nohup loop on reboot to re activate the node post triage. Also run the nohup loop in a node local tmux session just to be safe.

```bash
nohup bash -c "while true; do ip route add default via 192.168.1.101; sleep 60; done" &
```

or add a permanent systemd service to do this periodically


```bash
mkdir -p /etc/systemd/system
mkdir -p /usr/local/bin

cat > /etc/systemd/system/clustergw.service <<EOF
[Unit]
Description=Service to add specific routes
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=30
User=root
ExecStart=-/usr/bin/ip route add default via 192.168.1.101

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now clustergw.service
```

