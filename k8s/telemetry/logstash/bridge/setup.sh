set -e

OPTION=$1
NAME=${NAME:?deployment name}
CONFIG=${CONFIG:?Required to set $CONFIG}
KAFKA=${KAFKA:?kafka endpoints yaml file}
ELASTIC=${ELASTIC:?elastic endpoints yaml file}

function create_yaml() {
      helm template atscale-$NAME . --debug --output-dir out/$CONFIG -f values/$CONFIG.yaml -f $KAFKA -f $ELASTIC --set name=$NAME
}

if [ -z "$OPTION" ]; then
	echo "$0 [install | teardown | create-yaml]"
else
	case $OPTION in
		install)
      create_yaml
      kubectl apply -n monitoring -f out/$CONFIG/atscale/templates
			;;
		teardown)
      kubectl delete -n monitoring -f out/$CONFIG/atscale/templates
			;;
    create-yaml)
      create_yaml
      ;;
	esac
fi
