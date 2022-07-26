# Reboot Container

## Container Image:
The steps below will create a pod with scripts that will help with rebooting a node on which it is running.

```bash

cp reboot-machine.sh ../../testing-simple-binaries/
cp cleanup-host.sh ../../testing-simple-binaries/
sed -i '/FROM fedora:30/a RUN dnf install -y ipmitool' ../../testing-simple-binaries/Dockerfile
cd ../../testing-simple-binaries && DOCKER_TAG="orca" make docker-build
docker tag sandstone:orca prt-registry.sova.intel.com/sandstone:orca
docker push prt-registry.sova.intel.com/sandstone:orca
```

## YAMLS
`killer-pod.yaml` - This yaml will setup a daemonset on hosts that are tagged `rebootablenode`. 
`killer-pod-reboot.yaml` - This yaml will replace the previous daemonset with the variable to reboot the node. The `maxUnavailable` value will determine how many machines will be rebooted at a given time.
`cleanup-pod.yaml` - This will remove the file on host that prevents the previous pod to constantly keep rebooting the host it lands on.
