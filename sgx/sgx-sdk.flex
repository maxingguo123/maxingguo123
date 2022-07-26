load "${env.WORKSPACE}/sgx/sgx-sdk.base"

env.KUBECTL_ARGS="--kubeconfig=/srv/kube/config.flex"
env.JENKINS_NODE_LABEL="spr-sgx-tdx-pipeline"
env.NS="spr-sgx-tdx"
