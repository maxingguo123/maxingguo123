set -e

OPTION=$1
NAME=${NAME:=atscale}
CONFIG=${CONFIG:?Required to set $CONFIG}
ELASTIC=${ELASTIC:?endpoints yaml file}
SHARED=${SHARED:=../shared}

function create_yaml() {
  mkdir -p tmp
  cp -rf $SHARED tmp
      helm template $NAME . --debug --output-dir out/$CONFIG/$NAME -f values/$CONFIG.yaml -f $ELASTIC
}

if [ -z "$OPTION" ]; then
    echo "$0 [install | teardown | create-yaml]"
else
    case $OPTION in
        install)
            create_yaml
            kubectl apply -f out/$CONFIG/$NAME/fluentd-es/templates/
            ;;
        teardown)
            kubectl delete -f out/$CONFIG/$NAME/fluentd-es/templates/
            ;;
        create-yaml)
            create_yaml
            ;;
    esac
fi
