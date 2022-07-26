set -e

OPTION=$1
NAME=${NAME:=atscale}
NAMESPACE=monitoring
CONFIG=${CONFIG:?Required to set $CONFIG}

function get_endpoints_yaml() {
  nodes=`kubectl get nodes --selector=kafka=true -owide -o jsonpath='{range.items[*].status.addresses[?(@.type=="InternalIP")]}{.address}{"\n"}{end}'`
  port=31090
  printf "kafka:\n"
  for node in $nodes
  do
    printf -- "- host: %s\n" "$node"
    printf "  port: %d\n" "$port"
    port=$((port+1))
  done
}

function create_yaml() {
  helm repo add confluentinc https://confluentinc.github.io/cp-helm-charts/
  helm repo update
	rm -rf cp-helm-charts
	helm fetch confluentinc/cp-helm-charts --version 0.6.1 --untar
  helm template cp-helm-charts --name-template $NAME --version 0.6.1 -f values/$CONFIG.yaml --output-dir out/$CONFIG --namespace $NAMESPACE
  if [ -n "$KSQL" ]; then
		create_ksql_yaml
	fi
  cp jmx-configmap.yaml out/$CONFIG/cp-helm-charts/charts/cp-kafka/templates/jmx-configmap.yaml
}

function create_ksql_yaml() {
	for qfile in queries/*.sql; do
		name=`basename $qfile .sql`
		cp $qfile cp-helm-charts/charts/cp-ksql-server/queries.sql
		helm template cp-helm-charts/charts/cp-ksql-server --name-template $NAME-$name -f values/${CONFIG}-ksql.yaml --set kafka.bootstrapServers="PLAINTEXT://$NAME-cp-kafka-headless:9092" --output-dir out/$CONFIG/ksql-$name --namespace $NAMESPACE
	done
}

function install_ksql() {
	name=$1
	kubectl apply -f out/$CONFIG/ksql-$name/cp-ksql-server/templates --namespace $NAMESPACE
  sleep 5 # sleep a bit for pods to start creating
  kubectl wait -n monitoring --for=condition=Ready pod -l app=cp-ksql-server,release=$NAME-$name --timeout=15m
}

if [ -z "$OPTION" ]; then
  echo "$0 [install | teardown | getbrokers | create-yaml]"
else
  case $OPTION in
    install)
      create_yaml
      kubectl create namespace $NAMESPACE || true
      kubectl apply -f out/$CONFIG/cp-helm-charts/charts/cp-zookeeper/templates --namespace $NAMESPACE
      sleep 5 # sleep a bit for pods to start creating
      kubectl wait -n monitoring --for=condition=Ready pod --selector=app=cp-zookeeper --timeout=15m
      kubectl apply -f out/$CONFIG/cp-helm-charts/charts/cp-kafka/templates --namespace $NAMESPACE
      sleep 5 # sleep a bit for pods to start creating
      kubectl wait -n monitoring --for=condition=Ready pod --selector=app=cp-kafka --timeout=15m
      if [ -n "$KSQL" ]; then
          # kubectl apply -f out/$CONFIG/cp-helm-charts/charts/cp-schema-registry/templates --namespace $NAMESPACE
          # sleep 5 # sleep a bit for pods to start creating
          # kubectl wait -n monitoring --for=condition=Ready pod --selector=app=cp-schema-registry --timeout=15m
				for qfile in queries/*.sql; do
					name=`basename $qfile .sql`
					install_ksql $name
				done
      fi
      kubectl apply -f cp-zookeeper-jmx-headless.yaml --namespace $NAMESPACE
      kubectl apply -f cp-kafka-jmx-headless.yaml --namespace $NAMESPACE
      if [ -n "$KSQL" ]; then
        kubectl apply -f cp-ksql-jmx-headless.yaml --namespace $NAMESPACE
      fi
      kubectl apply -f kafka-monitor.yaml --namespace $NAMESPACE
      get_endpoints_yaml | tee out/$CONFIG/cp-helm-charts/charts/cp-kafka/endpoints.yaml
      ;;
		install-ksql)
		    create_ksql_yaml
				for qfile in queries/*.sql; do
					name=`basename $qfile .sql`
					install_ksql $name
				done
        kubectl apply -f cp-ksql-jmx-headless.yaml --namespace $NAMESPACE
				;;
    teardown)
      kubectl delete -f out/$CONFIG/cp-helm-charts/charts/cp-zookeeper/templates --namespace $NAMESPACE
      kubectl delete -f out/$CONFIG/cp-helm-charts/charts/cp-kafka/templates --namespace $NAMESPACE
      if [ -n "$KSQL" ]; then
				for qfile in queries/*.sql; do
					name=`basename $qfile .sql`
      		kubectl delete -f out/$CONFIG/ksql-$name/cp-ksql-server/templates --namespace $NAMESPACE
				done
      fi
      ;;
		teardown-ksql)
				create_ksql_yaml
				for qfile in queries/*.sql; do
					name=`basename $qfile .sql`
      		kubectl delete -f out/$CONFIG/ksql-$name/cp-ksql-server/templates --namespace $NAMESPACE
				done
			;;
    release-disks)
      kubectl delete pvc -n $NAMESPACE --selector=app=cp-kafka
      kubectl delete pvc -n $NAMESPACE --selector=app=cp-zookeeper
      ;;
    getendpoints)
      get_endpoints_yaml | tee out/$CONFIG/cp-helm-charts/charts/cp-kafka/endpoints.yaml
      ;;
    create-yaml)
      create_yaml
      ;;
    create-ksql-yaml)
      create_ksql_yaml
      ;;
  esac
fi
