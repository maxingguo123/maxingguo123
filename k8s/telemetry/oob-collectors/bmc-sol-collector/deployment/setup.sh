#!/bin/bash
set -e

OPTION=$1
NAME=${NAME:=atscale}
CONFIG=${CONFIG:?Required to set $CONFIG}
NAMESPACE=monitoring

function create_yaml() {
    helm template $NAME . --output-dir out/$CONFIG -f values/values.yaml -f values/$CONFIG.yaml --namespace $NAMESPACE
}

if [ -z "$OPTION" ]; then
    echo "$0 [install | teardown | create-yaml]"
else
    case $OPTION in
        install)
            create_yaml
            kubectl create namespace $NAMESPACE || true
            kubectl apply -f out/$CONFIG/sol-collector/templates/ --namespace $NAMESPACE
            ;;
        teardown)
            kubectl delete -f out/$CONFIG/sol-collector/templates/ --namespace $NAMESPACE
            ;;
        create-yaml)
            create_yaml
            ;;
    esac
fi
