load "${env.WORKSPACE}/ive-povray/ive-povray.base"

env.JENKINS_NODE_LABEL="spr-pipeline"
env.NS="sapphire"
env.JENKINS_TEST_BINARY="\\/run_content.sh -t 24"
env.JENKINS_TEST_ARGS=""
env.JOB_RUNTIME=93600
env.KUBECTL_ARGS="--kubeconfig=/srv/kube/config.flex"
