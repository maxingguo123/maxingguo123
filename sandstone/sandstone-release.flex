load "${env.WORKSPACE}/sandstone/sandstone-release.base"

env.KUBECTL_ARGS="--kubeconfig=/srv/kube/config.flex"
env.JENKINS_TEST_ARGS="-vv --beta -T 3600000 --disable=@locks_cross_cacheline"
