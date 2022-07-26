#!/bin/bash

KUBECONFIG=${KUBECONFIG:?}
PORT=${PORT:-5601}

while true; do
    now=$(date -u +"%Y-%m-%dT%T.%3NZ")
    echo "$now: running port-forward ..."
    time kubectl port-forward --address=0.0.0.0 -n monitoring svc/kibana-atscale-kb-http $PORT:5601
    sleep 1
done
