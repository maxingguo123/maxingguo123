load "${env.WORKSPACE}/jasper/cpu-check.base"

env.KUBECTL_ARGS="--kubeconfig=/srv/kube/config.flex"
env.JOB_RUNTIME=900
