set -e

OPTION=$1
NAME=${NAME:?Deployment set name}
CONFIG=${CONFIG:?Required to set $CONFIG}
KAFKA=${KAFKA:?kafka endpoints yaml file}
ELASTIC=${ELASTIC:?elastic endpoints yaml file}

function create_yaml() {
      helm template $NAME . --debug --output-dir out/$CONFIG -f values/$CONFIG.yaml -f $KAFKA -f $ELASTIC --set name=fluentd-bridge-$NAME
}

if [ -z "$OPTION" ]; then
	echo "$0 [install | teardown | create-yaml]"
else
	case $OPTION in
		install)
      create_yaml
      kubectl apply -f out/$CONFIG/fluentd-bridge/templates
			;;
		teardown)
      kubectl delete -f out/$CONFIG/fluentd-bridge/templates
			;;
    create-yaml)
      create_yaml
      ;;
	esac
fi
