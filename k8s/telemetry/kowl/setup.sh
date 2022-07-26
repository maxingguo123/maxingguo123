#!/bin/bash
set -e

OPTION=$1
NAME=${NAME:=atscale}
CONFIG=${CONFIG:?'env is required'}
NS=${NS:=telemetry}

function create_yaml() {
      helm template $NAME ./kowl --namespace=${NS} --debug --output-dir out/$CONFIG/$NAME -f values/$CONFIG.yaml
}

if [ -z "$OPTION" ]; then
	echo "$0 [install | teardown | create-yaml]"
else
	case $OPTION in
		install)
      kubectl create ns $NS || true
      create_yaml
			kubectl apply -f out/$CONFIG/$NAME/kowl/templates/
			;;
		teardown)
			kubectl delete -f out/$CONFIG/$NAME/kowl/templates/
			;;
    create-yaml)
      create_yaml
      ;;
	esac
fi


