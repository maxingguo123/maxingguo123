set -e

OPTION=$1
NAME=${NAME:=atscale}
CONFIG=${CONFIG:?Required to set $CONFIG}
NAMESPACE=monitoring

function create_yaml() {
      helm template $NAME . --output-dir out/$CONFIG -f values/$CONFIG.yaml --debug
      cp -rf manifests/* out/$CONFIG/kube-prometheus-atscale/templates
}

if [ -z "$OPTION" ]; then
	echo "$0 [install | teardown | create-yaml]"
else
	case $OPTION in
		install)
      create_yaml
      kubectl create namespace monitoring || true
      kubectl delete secret -n monitoring grafana-datasources || true
      kubectl create secret -n monitoring generic grafana-datasources --from-file=datasources.yaml=config/grafana-data-sources.yaml
			kubectl apply -f out/$CONFIG/kube-prometheus-atscale/templates/setup
      sleep 5 # wait a bit before the statefulsets spin up container
      kubectl wait -n $NAMESPACE --for=condition=Ready pod --selector=app.kubernetes.io/name=prometheus-operator --timeout=15m
			kubectl apply -f out/$CONFIG/kube-prometheus-atscale/templates/
			;;
		teardown)
			kubectl delete -f out/$CONFIG/kube-prometheus-atscale/templates/
			;;
    teardown-operator)
			kubectl delete -f out/$CONFIG/kube-prometheus-atscale/templates/setup
      ;;
    release-disks)
      kubectl delete pvc -n $NAMESPACE --selector=app=grafana
      kubectl delete pvc -n $NAMESPACE --selector=app=prometheus
      ;;
    create-yaml)
      create_yaml
      ;;
	esac
fi
