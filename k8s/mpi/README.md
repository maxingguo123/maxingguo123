# MPI based distribted jobs in a K8S Cluster.

## Pre-Requisite
Version: v0.2.3  
File: `mpi-operator.yaml`  
Source: https://github.com/kubeflow/mpi-operator/blob/v0.2.3/deploy/v1alpha2/mpi-operator.yaml
Apply the `mpi-operator.yaml` in the cluster where you would like to run the content. This file creates a Custom Resource Definition (CRD) that will create the controller<->worker model in the cluster.

## Workload
We have pre-defined a few conditions for our workload.
* Two executors will not run on the same system.
* There is one controller in this deployment. `TODO: Make this configurable`
* All systems including the controller machines should be label with a common label that can be referenced during deployment.
* All containers will be privileged when executing and will have access to a variety of host paths like /sys, /proc /etc/journal, etc.

## How-To
1. Create a sample env file like the one in this folder.

```bash
  cat env.sh
  export SANDSTONE_DEPLOYMENT=./mpi/impi-workload.yaml
  export JENKINS_NODE_LABEL=impi-runner
  export JENKINS_TEST_TAG=jasper-impi-gromacs-01-v0.1
  export JENKINS_TEST_LABEL=impi-gromacs
  export 'JENKINS_TEST_BINARY=\/opt\/intel\/compilers_and_libraries_2018.3.222\/linux\/mpi\/intel64\/bin\/mpirun'
  export 'JENKINS_TEST_ARGS=-v -bind-to none -map-by slot -genv LD_LIBRARY_PATH \/usr\/local\/gromacs\/lib \/tests\/gmx_mpi mdrun -deffnm 1cta_nvt -nsteps 10000'
  export REPLICAS=$(( $(kubectl get nodes --no-headers -l=${JENKINS_NODE_LABEL}=true | grep -v NotReady | wc -l ) - 1 ))
```

2. Run the bash script from this repository

```bash
  bash -x jenkins-cluster-cd-specific.sh
```

## TODO
* Investigate if we can add `initContainers` to the controller and worker pods
