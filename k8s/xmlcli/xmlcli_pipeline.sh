#!/bin/bash

# Set up default parameters
: ${K8STIMEOUT:=600}
: ${CLEANUP_TIMEOUT:=60}
: ${XC_NAMESPACE:=default}
: ${XC_LABEL:=xmlcli}
: ${NS:="mgmt"}
: ${MAXREBOOTS:=24}
: ${REBOOT_TIMEOUT:="5400"} #Timeout in seconds
DOCKER_IMAGE="xmlcli-v3.0"

# Set XmlCli-specific power-cycle-test.sh parameters and expose settings to
export REBOOT_TYPE="cold" REBOOTLABEL=$XC_LABEL
export NS MAXREBOOTS REBOOT_TIMEOUT

# Disable TLS verification for central CI server
KUBECTL_XMLCLI_XTRA_ARGS="--insecure-skip-tls-verify"

# Functions copy+pasted since sourcing the power-cycle-test.sh would cause unwanted prints
function apply_reboot_yaml()
{
  sed \
    -e "s/REBOOTTYPE/${REBOOT_TYPE}/" \
    -e "s/NAMESPACE/${NS}/" \
    -e "s/MAXREBOOTS/${MAXREBOOTS}/" \
    -e "s/REBOOTLABEL/${REBOOTLABEL}/" ${1} | kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} apply -f -
  RET=$?
  sleep 30
  if [ $RET -ne 0 ]; then
    echo "Creating daemonset ${1} failed!!"
    return 1
  fi
  return 0
}

function apply_xmlcli_yaml()
{
  sed \
    -e "s/NAMESPACE/$XC_NAMESPACE/" \
    -e "s/XC_CMD_OP/${2}/" \
    -e "s/XC_CMD_KNOB/$XC_KNOB/" \
    -e "s/SANDSTONE_NODE_LABEL/$XC_LABEL/" \
    -e "s/SANDSTONE_NAME/xmlcli-${2}/" \
    -e "s/DOCKER_TAG/${DOCKER_IMAGE}/" \
    -e "s/REGISTRY/prt-registry.sova.intel.com/" \
    -e "s/REPO/sandstone/" ${1} | kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} apply -f -
  RET=$?
  sleep 30
  if [ $RET -ne 0 ]; then
    echo "Creating daemonset ${1} failed!!"
    return 1
  fi
  return 0
}

function delete_reboot_yaml()
{
  sed \
    -e "s/REBOOTTYPE/${REBOOT_TYPE}/" \
    -e "s/NAMESPACE/${NS}/" \
    -e "s/MAXREBOOTS/${MAXREBOOTS}/" \
    -e "s/REBOOTLABEL/${REBOOTLABEL}/" ${1} | kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} delete -f -
  RET=$?
  sleep 30
  if [ $RET -ne 0 ]; then
    echo "Deleting daemonset ${1} failed!!"
    return 1
  fi
  return 0
}

function delete_xmlcli_yaml()
{
  sed \
    -e "s/NAMESPACE/$XC_NAMESPACE/" \
    -e "s/XC_CMD_OP/${2}/" \
    -e "s/XC_CMD_KNOB/$XC_KNOB/" \
    -e "s/SANDSTONE_NODE_LABEL/$XC_LABEL/" \
    -e "s/SANDSTONE_NAME/xmlcli-${2}/" \
    -e "s/DOCKER_TAG/${DOCKER_IMAGE}/" \
    -e "s/REGISTRY/prt-registry.sova.intel.com/" \
    -e "s/REPO/sandstone/" ${1} | kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} delete -f -
  RET=$?
  sleep 30
  if [ $RET -ne 0 ]; then
    echo "Deleting daemonset ${1} failed!!"
    return 1
  fi
  return 0
}

function download_reboot_collateral
{
  # TODO: Change to using files in the repo instead of curl-ing them
  curl -OL https://gitlab-mirror-fm.devtools.intel.com/sandstone/cluster-infra/-/raw/master/k8s/reboot/killer-pod.yaml
  curl -OL https://gitlab-mirror-fm.devtools.intel.com/sandstone/cluster-infra/-/raw/master/k8s/reboot/killer-pod-reboot.yaml
  curl -OL https://gitlab-mirror-fm.devtools.intel.com/sandstone/cluster-infra/-/raw/master/k8s/reboot/cleanup-pod.yaml
  curl -OL https://gitlab-mirror-fm.devtools.intel.com/sandstone/cluster-infra/-/raw/master/k8s/reboot/power-cycle-test.sh
  chmod +x power-cycle-test.sh
}

function cleanup_reboot
{
  apply_reboot_yaml cleanup-pod.yaml
    # Wait for cleanup to complete.
   END=$((SECONDS+${CLEANUP_TIMEOUT}))
  while [ ${SECONDS} -lt ${END} ]; do
    # Check if rollout is complete
    if [ "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get ds -n ${NS} killer-pod -ojson | jq .status.desiredNumberScheduled)" -eq "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get ds -n ${NS} killer-pod -ojson | jq .status.numberReady)" ]; then
      echo "Cleanup complete"
      break
    fi
    sleep 10
  done
  delete_reboot_yaml cleanup-pod.yaml
}

function xmlcli_program
{
  # Run XmlCli to program knobs
  apply_xmlcli_yaml xmlcli.yaml progknobs

  # Wait for programming to complete
  end=$((SECONDS+${K8STIMEOUT}))
  while [[ $SECONDS -lt $end ]]; do
    if [ "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get ds -n ${XC_NAMESPACE} xmlcli-progknobs -ojson | jq .status.desiredNumberScheduled)" -eq "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get ds -n ${XC_NAMESPACE} xmlcli-progknobs -ojson | jq .status.numberReady)" ]; then
      echo "XmlCli programming complete"
      break
    fi
    sleep 10
  done

  # Gather results
  kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get -n $XC_NAMESPACE ds/xmlcli-progknobs
  if [ $SECONDS -gt $end ]; then
    echo "Warning: XmlCli knob programming failed on one or more nodes! Check below for details."
    # If there are leftover deployments from crashed nodes, this might cause false failures
    # The age timestamps from the below statement can help users determine if there were real failures or not.
    kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get -n ${XC_NAMESPACE} po | grep xmlcli-progknobs
  fi

  # Tear down XmlCli deployment
  delete_xmlcli_yaml xmlcli.yaml progknobs
}

function xmlcli_check
{
  apply_xmlcli_yaml xmlcli.yaml readknobs

  # Wait for check to complete
  end=$((SECONDS+${K8STIMEOUT}))
  while [[ $SECONDS -lt $end ]]; do
    if [ "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get ds -n ${XC_NAMESPACE} xmlcli-readknobs -ojson | jq .status.desiredNumberScheduled)" -eq "$(kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get ds -n ${XC_NAMESPACE} xmlcli-readknobs -ojson | jq .status.numberReady)" ]; then
      echo "XmlCli check complete"
      break
    fi
    sleep 10
  done

  # Gather results
  kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get -n $XC_NAMESPACE ds/xmlcli-readknobs
  if [ $SECONDS -gt $end ]; then
    echo "Warning: XmlCli knob check failed on one or more nodes! Check below for details."
    # If there are leftover deployments from crashed nodes, this might cause false failures
    # The age timestamps from the below statement can help users determine if there were real failures or not.
    kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} get -n ${XC_NAMESPACE} po | grep xmlcli-readknobs
  fi

  # Tear down the XmlCli deployment
  delete_xmlcli_yaml xmlcli.yaml readknobs
}

function main()
{
  # Download required files
  download_reboot_collateral

  # Clean up any remnants of previous killer-pod deployments
  cleanup_reboot

  # Deploy killer-pod for later
  ./power-cycle-test.sh -s

  # Program knobs
  xmlcli_program

  # Reboot cluster to apply changes
  ./power-cycle-test.sh -r

  # Ensure that knobs were actually set
  xmlcli_check
}

# Run XmlCli flow
main
