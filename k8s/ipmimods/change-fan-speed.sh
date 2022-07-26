#!/bin/bash

# Script to change the fan speeds of systems in cluster.
#
: ${SPEEDMODE:="reset"}
: ${SPEEDVALUE:=""}
: ${NS:="mgmt"}
: ${SET_TIMEOUT:="900"} #Timeout in seconds
: ${NODELABEL:="fanspeednode"}

KUBECTL_XTRA_ARGS="--insecure-skip-tls-verify"

function apply_yaml()
{
  sed \
    -e "s/SPEEDMODE/${SPEEDMODE}/" \
    -e "s/NAMESPACE/${NS}/" \
    -e "s/SPEEDVALUE/${SPEEDVALUE}/" \
    -e "s/NODELABEL/${NODELABEL}/" ${1} | kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} apply -f -
  RET=$?
  sleep 30
  if [ $RET -ne 0 ]; then
    echo "Creating daemonsets ${1} failed!!"
    return 1
  fi
  return 0
}

function delete_yaml()
{
  sed \
    -e "s/SPEEDMODE/${SPEEDMODE}/" \
    -e "s/NAMESPACE/${NS}/" \
    -e "s/SPEEDVALUE/${SPEEDVALUE}/" \
    -e "s/NODELABEL/${NODELABEL}/" ${1} | kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} delete -f -
  RET=$?
  sleep 30
  if [ $RET -ne 0 ]; then
    echo "Deleting daemonsets ${1} failed!!"
    return 1
  fi
  return 0
}

function do_job()
{
  if [ ! -f ipmi-fan-set.yaml ]; then
    curl -OL https://gitlab-mirror-fm.devtools.intel.com/sandstone/cluster-infra/raw/master/k8s/ipmimods/ipmi-fan-set.yaml
  fi

  TOTAL_MACHINES=$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get nodes -l=${NODELABEL}=true --no-headers | grep -v NotReady | wc -l)

  apply_yaml ipmi-fan-set.yaml

  # Time to wait for all the systems to complete their operation
  END=$((SECONDS+${SET_TIMEOUT}))
  while [ ${SECONDS} -lt ${END} ]; do
    # Check if rollout is complete
    if [ "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get ds -n ${NS} ipmi-fan-set -ojson | jq .status.updatedNumberScheduled)" != "null" ] && [ "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get ds -n ${NS} ipmi-fan-set -ojson | jq .status.numberReady)" -ge ${TOTAL_MACHINES} ]; then
      echo " Rollout complete"
      break
    fi
    sleep 10
  done
  # We either have completed the reboot on all the systems or have killed a few systems and run out the clock on the reboot timeout. Eitherways, it is time to clean up and keep going.
  delete_yaml ipmi-fan-set.yaml
}

case "$SPEEDMODE" in
  "set") \
    if [ -z "$SPEEDVALUE" ]; then
      echo "Speed value not set"
      exit 1
    fi;;
  "reset") break;;
  "*") echo "Unknown mode. Please check the script for options"; exit 1;;
esac

do_job
