set -e

OPTION=$1
NAME=${NAME:=atscale}
NAMESPACE=monitoring
CONFIG=${CONFIG:?Required to set $CONFIG}

function create_yaml() {
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  rm -rf prometheus-blackbox-exporter
  helm pull prometheus-community/prometheus-blackbox-exporter --untar
  helm template prometheus-blackbox-exporter --name-template $NAME -f prometheus-blackbox-exporter/values.yaml -f values/$CONFIG.yaml --output-dir out/$CONFIG --namespace $NAMESPACE
}

if [ -z "$OPTION" ]; then
  echo "$0 [install | teardown | getbrokers | create-yaml]"
else
  case $OPTION in
    install)
      create_yaml
      kubectl apply -f out/$CONFIG/prometheus-blackbox-exporter/templates --namespace $NAMESPACE
      ;;
    teardown)
      kubectl delete -f out/$CONFIG/prometheus-blackbox-exporter/templates --namespace $NAMESPACE
      ;;
    create-yaml)
      create_yaml
      ;;
  esac
fi
