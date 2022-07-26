#!/bin/bash

# Possible reboot types
#  * cold - All the power rails lose power and have their voltage dropped to zero before being powered back on
#  * warm - The power rails all stay up but the CPU goes through a reset without losing power.
#
: ${REBOOT_TYPE:="cold"}
: ${NS:="mgmt"}
: ${MAXREBOOTS:=24}
: ${REBOOT_TIMEOUT:="5400"} #Timeout in seconds
: ${REBOOTLABEL:="rebootablenode"}

KUBECTL_XTRA_ARGS="--insecure-skip-tls-verify"
ACTION=""

function usage()
{
  echo ""
  echo "Usage: ${0} [-s][-r][-c]"
  echo ""
  echo "r: reboot the machines"
  echo "s: setup machines for reboot test"
  echo "c: Clean counter on host"
  echo ""
  exit 1
}

function apply_yaml()
{
  sed \
    -e "s/REBOOTTYPE/${REBOOT_TYPE}/" \
    -e "s/NAMESPACE/${NS}/" \
    -e "s/MAXREBOOTS/${MAXREBOOTS}/" \
    -e "s/REBOOTLABEL/${REBOOTLABEL}/" ${1} | kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} apply -f -
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
    -e "s/REBOOTTYPE/${REBOOT_TYPE}/" \
    -e "s/NAMESPACE/${NS}/" \
    -e "s/MAXREBOOTS/${MAXREBOOTS}/" \
    -e "s/REBOOTLABEL/${REBOOTLABEL}/" ${1} | kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} delete -f -
  RET=$?
  sleep 30
  if [ $RET -ne 0 ]; then
    echo "Deleting daemonsets ${1} failed!!"
    return 1
  fi
  return 0
}

function run-setup()
{
  #if [ ! -f killer-pod.yaml ]; then
    curl -OL https://gitlab-mirror-fm.devtools.intel.com/sandstone/cluster-infra/raw/master/k8s/reboot/killer-pod.yaml
  #fi

  apply_yaml killer-pod.yaml
}

function run-reboot()
{
  #if [ ! -f killer-pod-reboot.yaml ]; then
    curl -OL https://gitlab-mirror-fm.devtools.intel.com/sandstone/cluster-infra/raw/master/k8s/reboot/killer-pod-reboot.yaml
  #fi
  #if [ ! -f cleanup-pod.yaml ]; then
    curl -OL https://gitlab-mirror-fm.devtools.intel.com/sandstone/cluster-infra/raw/master/k8s/reboot/cleanup-pod.yaml
  #fi
  TOTAL_MACHINES=$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get nodes -l=${REBOOTLABEL}=true --no-headers | grep -v NotReady | wc -l)
  apply_yaml killer-pod-reboot.yaml
  # Time to wait for all the systems to complete their reboots.
  END=$((SECONDS+${REBOOT_TIMEOUT}))
  while [ ${SECONDS} -lt ${END} ]; do
    # Check if rollout is complete
    if [ "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get ds -n ${NS} killer-pod -ojson | jq .status.updatedNumberScheduled)" != "null" ] && [ "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get ds -n ${NS} killer-pod -ojson | jq .status.numberReady)" -ge ${TOTAL_MACHINES} ]; then
      echo " Rollout complete"
      break
    fi
    sleep 10
  done
  # We either have completed the reboot on all the systems or have killed a few systems and run out the clock on the reboot timeout. Eitherways, it is time to clean up and keep going.
  delete_yaml killer-pod-reboot.yaml
  apply_yaml cleanup-pod.yaml
  # Wait for cleanup to complete.
   END=$((SECONDS+${REBOOT_TIMEOUT}))
  while [ ${SECONDS} -lt ${END} ]; do
    # Check if rollout is complete
    if [ "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get ds -n ${NS} killer-pod -ojson | jq .status.desiredNumberScheduled)" -eq "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get ds -n ${NS} killer-pod -ojson | jq .status.numberReady)" ]; then
      echo "Cleanup complete"
      break
    fi
    sleep 10
  done

  delete_yaml cleanup-pod.yaml
}

function run-cleancounter()
{
  #if [ ! -f cleanup-counter-pod.yaml ]; then
    curl -OL https://gitlab-mirror-fm.devtools.intel.com/sandstone/cluster-infra/raw/master/k8s/reboot/cleanup-counter-pod.yaml
  #fi
  apply_yaml cleanup-counter-pod.yaml

  END=$((SECONDS+${REBOOT_TIMEOUT}))
  while [ ${SECONDS} -lt ${END} ]; do
    # Check if rollout is complete
    if [ "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get ds -n ${NS} killer-pod -ojson | jq .status.desiredNumberScheduled)" -eq "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XTRA_ARGS} get ds -n ${NS} killer-pod -ojson | jq .status.numberReady)" ]; then
      echo "Cleanup complete"
      break
    fi
    sleep 10
  done

  delete_yaml cleanup-counter-pod.yaml
}



while getopts "src" o
do
  case $o in
    s) ACTION=setup;;
    r) ACTION=reboot;;
    c) ACTION=cleancounter;;
  esac
done

if [ -z "${ACTION}" ]; then usage; fi

run-${ACTION}
