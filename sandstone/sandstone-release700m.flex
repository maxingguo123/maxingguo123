load "${env.WORKSPACE}/sandstone/sandstone-release.base"

env.KUBECTL_ARGS="--kubeconfig=/srv/kube/config.flex"
env.JENKINS_TEST_ARGS="-vv --beta -t 1m -T 700m --disable=@locks_cross_cacheline"
env.JOB_RUNTIME=42000
