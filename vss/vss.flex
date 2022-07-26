load "${env.WORKSPACE}/vss/vss.base"

env.KUBECTL_ARGS="--kubeconfig=/srv/kube/config.flex"
env.JENKINS_TEST_ARGS="EST_10"
//env.JOB_RUNTIME=39600
env.ITERATIONS=4
