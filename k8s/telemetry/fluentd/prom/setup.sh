set -e

OPTION=$1
NAME=${NAME:=atscale}
CONFIG=${CONFIG:?Required to set $CONFIG}
SHARED=${SHARED:=../shared}

function create_yaml() {
  mkdir -p tmp
  cp -rf $SHARED tmp
  if [ -z "$ELASTIC" ]; then
      echo " Warning: Elastic endpoint not set. Assuming no logs to elasticsearch"
      helm template $NAME . --debug --output-dir out/$CONFIG/$NAME -f values/$CONFIG.yaml
  else
      helm template $NAME . --debug --output-dir out/$CONFIG/$NAME -f values/$CONFIG.yaml -f $ELASTIC
  fi
}

if [ -z "$OPTION" ]; then
	echo "$0 [install | teardown | create-yaml]"
else
	case $OPTION in
		install)
      create_yaml
			kubectl apply -f out/$CONFIG/$NAME/fluentd-prom/templates/
			;;
		teardown)
			kubectl delete -f out/$CONFIG/$NAME/fluentd-prom/templates/
			;;
    create-yaml)
      create_yaml
      ;;
	esac
fi
