load "${env.WORKSPACE}/TSL/TSL.base"

env.JENKINS_TEST_TAG="spr-tsl-v1.0"
env.JENKINS_TEST_LABEL="spr-tsl"
env.JENKINS_NODE_LABEL="unifiednode"
env.JENKINS_TEST_BINARY=""
env.JENKINS_TEST_ARGS=""
env.TEST_RUNTIME=""
env.DRAGON_TYPE_ARG=""
env.DRAGON_ARGS_ARG=""
env.RUN_DRAGON_ARG=true
env.EXTRA_ARGS_ARG=""
env.JOB_RUNTIME=28800

env.KUBECTL_ARGS="--kubeconfig=/srv/kube/config.flex"
