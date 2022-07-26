load "${env.WORKSPACE}/helpers/idle.base"

env.JENKINS_NODE_LABEL="flex-pipeline"
env.NS="flex"
env.KUBECTL_ARGS="--kubeconfig=/srv/kube/config.flex"
env.JENKINS_TEST_ARGS="1h"
env.JOB_RUNTIME=3600
