#!/bin/bash

: ${KUBECTL_ARGS:=""}
: ${NS:="default"}
: ${REGISTRY:="prt-registry.sova.intel.com"}
: ${K8S_USER:=default}
: ${PRE_YAML:=""}

function delete() {

  sed \
    -e "s/SANDSTONE_NAME/$JENKINS_TEST_LABEL/" \
    -e "s/SANDSTONE_NODE_LABEL/$JENKINS_NODE_LABEL/" \
    -e "s/DOCKER_TAG/$JENKINS_TEST_TAG/" \
    -e "s/NAMESPACE/$NS/" \
    -e "s/REGISTRY/${REGISTRY}/" \
    "${WORKSPACE}/$1" | kubectl ${KUBECTL_ARGS} delete --insecure-skip-tls-verify -f -
}

function apply() {

  sed \
    -e "s/SANDSTONE_NAME/$JENKINS_TEST_LABEL/" \
    -e "s/SANDSTONE_NODE_LABEL/$JENKINS_NODE_LABEL/" \
    -e "s/DOCKER_TAG/$JENKINS_TEST_TAG/" \
    -e "s/NAMESPACE/$NS/" \
    -e "s/REGISTRY/${REGISTRY}/" \
    "${WORKSPACE}/$1" | kubectl ${KUBECTL_ARGS} apply --insecure-skip-tls-verify -f -
}

if [ -z "${PRE_YAML}" ]; then
  echo "PRE_YAML variable is empty. Exiting.."
  return
fi

if ! [[ "$1" =~ ^(apply|delete)$ ]]; then
  echo "Script can only two one of these operations"
  echo "apply, delete"
  return
fi

# Create a list of yamls to apply from the env variable
IFS="," read -a PYAML <<< ${PRE_YAML}

for eachyaml in ${PYAML[@]}; do
  $1 $eachyaml
done
