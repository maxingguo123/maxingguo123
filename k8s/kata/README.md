# Kata Containers for PRT

## What is this for
Kata containers allows us to run the test workload inside a lightweight VM to verify that content that works and identify issues on baremetal can also reproduce the same inside a VM. It also allows us to the stress the virtualization part of the system.

## How to use it.
* Label the nodes where you need to run the test with localadmin.io-kata-node=true.
* `kubectl apply -f kata-rbac.yaml`
* `kubectl apply -f kata-deploy.yaml`
* `kubectl apply -f kata-runtimeclass.yaml`
* This will automatically install the necessary binaries in all the machines that are part of the cluster
* This **DOES NOT** download the default kata image but will pull a patched version that has been tailored for this exercise.
* The kata-deploy container is hosted internally. `prt-registry.sova.intel.com/kata-deploy-bare:2.3.2`

## Changes to Kata
1. Fix the CPU layout in QEMU making it always a single socket machine with N cores against a N socket machine with 1 core each. Without that change, Dragon crashes if more than 4 sockets exist in a system.
2. Kata configuration has been changed to always allocate **80% of the total available physical memory and 80% of CPUs** to the VM.
3. Install a default qemu version and another with TDX support. *The system should have atleast WW50 TDX BKC, mainly qemu and firmware binaries*

## How to build the container
1. Clone `https://github.com/ganeshmaharaj/kata-containers`
2. `cd kata-containers && git checkout origin/tdx-2.3.2`
3. `tools/packaging/kata-deploy/local-build//kata-deploy-binaries-in-docker.sh -s --build=shim-v2` *This will build the runtime with custom patches*
4. `tools/packaging/kata-deploy/local-build//kata-deploy-binaries-in-docker.sh -s --build=kernel-tdx` *This will build the TDX guest kernel for kata*
These will build static binary packages under `tools/packaging/kata-deploy/local-build/build`
5. `docker build -t kata-deploy-bare:2.3.2.1 -f tools/packaging/kata-deploy/Dockerfile tools/packaging/kata-deploy/`
6. `docker tag kata-deploy-bare:2.3.2.1 prt-registry.sova.intel.com/kata-deploy-bare:2.3.2.1`
7. `docker push prt-registry.sova.intel.com/kata-deploy-bare:2.3.2.1`
This will pull kata prebuilt binaries from github, replace the shim with the patched version and add the TDX guest kernel to the package.

All this will be removed once the changes have made it into upstream kata and a new release has them.
