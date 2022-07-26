#!/bin/bash

: ${KUBECTL_ARGS:=""}
: ${NS:="default"}
: ${REGISTRY:="prt-registry.sova.intel.com"}
: ${AGGRESSOR_CONFIG:=""}
if [ -n "${AGGRESSOR_CONFIG}" ]; then
  source ${AGGRESSOR_CONFIG}
fi
if [ -z ${1-} ]; then
  TIME="300"
else
  TIME=${1}
fi

: ${K8S_USER:=default}

function get_logs() {
  echo
  PODS=$(kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get pods -n ${NS} -l name=$JENKINS_TEST_LABEL | grep $1 | awk '{print $1}')
  for POD in ${PODS}; do
    echo "POD: "${POD}
    kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify logs -n ${NS} ${POD}
  done
  echo
}

# We have to wait till the enviornment is clean. There is no point running them in parallel
function deployment_flush() {
  count=0

    while true; do
      kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify delete deployment -n ${NS} --all
      if [ $? -eq 0 ]; then
        break
      fi
      count=$((count+1))
      echo "Retry to cleanup test enviornment $count"
      date
    done
}

function deployment_delete() {
  loopcount=$2
  count=0
  ret=0

  OUT=$(sed \
    -e "s/SANDSTONE_BIN_PATH/$JENKINS_TEST_BINARY/" \
    -e "s/SANDSTONE_NAME/$JENKINS_TEST_LABEL/" \
    -e "s/SANDSTONE_NODE_LABEL/$JENKINS_NODE_LABEL/" \
    -e "s/SANDSTONE_TEST_ARGS/$JENKINS_TEST_ARGS/" \
    -e "s/DOCKER_TAG/$JENKINS_TEST_TAG/" \
    -e "s/NAMESPACE/$NS/" \
    -e "s/RUN_DRAGON_ARG/${RUN_DRAGON_ARG}/" \
    -e "s/DRAGON_ARGS_ARG/${DRAGON_ARGS_ARG}/" \
    -e "s/DRAGON_TYPE_ARG/${DRAGON_TYPE_ARG}/" \
    -e "s/EXTRA_ARGS_ARG/${EXTRA_ARGS_ARG}/" \
    -e "s/GB_USER_ARG/${GB_USER_ARG}/" \
    -e "s/GB_KEY_ARG/${GB_KEY_ARG}/" \
    -e "s/GB_ITERATIONS_ARG/${GB_ITERATIONS_ARG}/" \
    -e "s/REGISTRY/${REGISTRY}/" \
    -e "s/INIT_MSR_SET_VAL/$INIT_MSR_SET_VAL/" \
    -e "s/INIT_MSR_CPU_VAL/$INIT_MSR_CPU_VAL/" \
    -e "s/REPLICA_COUNT/$REPLICA_COUNT/" \
    "$AGGRESSOR_YAML" | kubectl ${KUBECTL_ARGS} delete --insecure-skip-tls-verify -f - 2>&1)

  if [ $? -ne 0 ] && [[ ! "${OUT}" =~ "not found" ]]; then
    while true; do
      # For good measure just delete the workload whether it is complete or not!
      OUT=$(kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify delete deployment -n ${NS} ${JENKINS_TEST_LABEL} 2>&1)
      if [ $? -eq 0] || [[ "${OUT}" =~ "not found" ]]; then
        break
      fi
      count=$((count+1))
      echo "Waiting $count (of $loopcount)"
      sleep 10
      if [ $count -eq "$loopcount" ]; then
        echo "Unable to delete workload ${JENKINS_TEST_LABEL}"
        return 2
      fi
    done
  fi

  sleep 30 # Additional wait to give Prometheus a chance to read metrics from fluentd
}

function deployment_test() {
  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get nodes -o wide
  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get po -o wide -n ${NS} -l name=$JENKINS_TEST_LABEL

  date
  sed \
    -e "s/SANDSTONE_BIN_PATH/$JENKINS_TEST_BINARY/" \
    -e "s/SANDSTONE_NAME/$JENKINS_TEST_LABEL/" \
    -e "s/SANDSTONE_NODE_LABEL/$JENKINS_NODE_LABEL/" \
    -e "s/SANDSTONE_TEST_ARGS/$JENKINS_TEST_ARGS/" \
    -e "s/DOCKER_TAG/$JENKINS_TEST_TAG/" \
    -e "s/NAMESPACE/$NS/" \
    -e "s/RUN_DRAGON_ARG/${RUN_DRAGON_ARG}/" \
    -e "s/DRAGON_ARGS_ARG/${DRAGON_ARGS_ARG}/" \
    -e "s/DRAGON_TYPE_ARG/${DRAGON_TYPE_ARG}/" \
    -e "s/EXTRA_ARGS_ARG/${EXTRA_ARGS_ARG}/" \
    -e "s/GB_USER_ARG/${GB_USER_ARG}/" \
    -e "s/GB_KEY_ARG/${GB_KEY_ARG}/" \
    -e "s/GB_ITERATIONS_ARG/${GB_ITERATIONS_ARG}/" \
    -e "s/REGISTRY/${REGISTRY}/" \
    -e "s/INIT_MSR_SET_VAL/$INIT_MSR_SET_VAL/" \
    -e "s/INIT_MSR_CPU_VAL/$INIT_MSR_CPU_VAL/" \
    -e "s/REPLICA_COUNT/$REPLICA_COUNT/" \
    "$AGGRESSOR_YAML" | kubectl ${KUBECTL_ARGS} apply --insecure-skip-tls-verify -f -
  RES=$?

  # We have setup scripts/run-once.sh to run for 300s
  # Kubernetes bug workaround
  date
  if [ ${RES} -eq 0 ]; then
    END=$((SECONDS+${TIME}))
    while [ ${SECONDS} -le ${END} ]; do
        sleep 30
    done
  fi
  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get -n ${NS} deployment/$JENKINS_TEST_LABEL
  date

  if [ $? -ne 0 ]; then
    kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get po -o wide -n ${NS}
    get_logs $JENKINS_TEST_LABEL
    echo "TEST FAILED"
    return 1
  fi

  get_logs $JENKINS_TEST_LABEL
  return 0
}


# Get the latest manifest and loop script
# There is a small possibility that the jenkins-latest does not match but we ignore this for now
#curl -O http://kojiclear.jf.intel.com/cgit/bdx/sandstone/plain/k8s/"$AGGRESSOR_YAML"

date
#We are in non stop mode. Delete any existing run
#First grab any logs
#This is needed as the previous run could have failed due to network issues
#The next test that runs when the network recovers should grab data from last run
#get_sandstone_logs $JENKINS_TEST_LABEL
#date
deployment_flush

date
deployment_test

date
# Wait for upto two hours. This should never happen unless we loose network
# connectivity to the cluster from jekins
deployment_delete $JENKINS_TEST_LABEL 24

date

echo "TEST PASSED"

