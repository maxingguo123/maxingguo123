#!/bin/bash
set -e

OPTION=$1
NAME=${NAME:=atscale}
CONFIG=${CONFIG:?'env is required'}

function create_yaml() {
      helm template $NAME ./cluster-health --namespace=kube-system --debug --output-dir out/$CONFIG/$NAME -f values/$CONFIG.yaml
}

if [ -z "$OPTION" ]; then
	echo "$0 [install | teardown | create-yaml]"
else
	case $OPTION in
		install)
      create_yaml
			kubectl apply -f out/$CONFIG/$NAME/cluster-health/templates/
			;;
		teardown)
			kubectl delete -f out/$CONFIG/$NAME/cluster-health/templates/
			;;
    create-yaml)
      create_yaml
      ;;
	esac
fi

