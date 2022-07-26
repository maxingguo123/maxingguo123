export SANDSTONE_DEPLOYMENT=./mpi/impi-workload.yaml
export JENKINS_NODE_LABEL=impi-runner
export JENKINS_TEST_TAG=jasper-impi-gromacs-01-v0.3
export JENKINS_TEST_LABEL=impi-gromacs
export 'JENKINS_TEST_BINARY=\/tests\/scripts\/run.sh'
export 'JENKINS_TEST_ARGS='
export REPLICAS=$(( $(kubectl get nodes --no-headers -l=${JENKINS_NODE_LABEL}=true | grep -v NotReady | wc -l ) - 1 ))
