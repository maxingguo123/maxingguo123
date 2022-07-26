set -e

OPTION=$1
NAME=${NAME:=atscale}
CONFIG=${CONFIG:?Required to set $CONFIG}
KAFKA=${KAFKA:?kafka endpoints yaml file}

function create_yaml() {
      helm template $NAME . --debug --output-dir out/$CONFIG/$NAME -f values/$CONFIG.yaml -f $KAFKA
}

if [ -z "$OPTION" ]; then
	echo "$0 [install | teardown | create-yaml]"
else
	case $OPTION in
		install)
      create_yaml
			kubectl apply -f out/$CONFIG/$NAME/fluentd-kafka/templates/
			;;
		teardown)
			kubectl delete -f out/$CONFIG/$NAME/fluentd-kafka/templates/
			;;
    create-yaml)
      create_yaml
      ;;
	esac
fi
