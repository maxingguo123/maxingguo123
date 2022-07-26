#!/bin/bash
KUBECONFIG=${KUBECONFIG:?}
PROM=${PROM:=k8s}
PORT=${PORT:=9090}

while true; do
    now=$(date -u +"%Y-%m-%dT%T.%3NZ")
    echo "$now: running port-forward ..."
    time kubectl port-forward --address 0.0.0.0 -n monitoring svc/prometheus-$PROM $PORT:9090
    sleep 1
done
