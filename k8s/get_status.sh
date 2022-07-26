#!/bin/bash

: ${NS:="default"}
function main() {
  get_sandstone_logs sandstone-runonce
}

function get_sandstone_logs() {
  echo
  PODS=$(kubectl get pods -n ${NS} | grep $1 | awk '{print $1}')
  for POD in ${PODS}; do
    kubectl logs -n ${NS} ${POD}
  done
  echo
}

main

