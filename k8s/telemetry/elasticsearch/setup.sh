set -e

OPTION=$1
NAME=${NAME:=atscale}
INDEX=${INDEX:=qpool_internal}
CONFIG=${CONFIG:?Required to set $CONFIG}

function create_yaml() {
      helm template $NAME . --output-dir out/$CONFIG -f values/$CONFIG.yaml --set name=elasticsearch-$NAME
      # HACK: helm assumes json is a yaml and add couple of lines on the top. Skip them
      # Find a better way to handle this.
      tail -n +3 out/$CONFIG/elasticsearch-$NAME/templates/index_template_settings.json > out/$CONFIG/elasticsearch-$NAME/templates/index_template_settings_fixed.json
      if [ -f "out/$CONFIG/elasticsearch-$NAME/templates/critical_index_template_settings.json" ]; then   
      	tail -n +3 out/$CONFIG/elasticsearch-$NAME/templates/critical_index_template_settings.json > out/$CONFIG/elasticsearch-$NAME/templates/critical_index_template_settings_fixed.json
      fi
}

function get_ip() {
  kubectl get svc -n monitoring elasticsearch-atscale-es-http-ilb > /dev/null
  ilbFound=$?
  if [ $ilbFound -ne 0 ]; then
    SVC=elasticsearch-atscale-es-http
    IP=`kubectl get svc -n monitoring | grep $SVC | awk '{print $3}'`
  else
    SVC=elasticsearch-atscale-es-http-ilb
    IP=`kubectl get svc -n monitoring | grep $SVC | awk '{print $4}'`
  fi
}

function get_endpoints_yaml() {
  IP=""
  get_ip
  PASSWD=`kubectl get secrets -n monitoring elasticsearch-$NAME-es-elastic-user '-o=jsonpath={.data.elastic}'|base64 --decode`
  printf "elasticsearch:\n"
  printf "  hosts:\n"
  printf -- "  - host: %s\n" "$IP"
  printf "    port: %d\n" "9200"
  printf "  scheme: https\n"
  printf "  user: elastic\n"
  printf "  password: %s\n" "$PASSWD"
  printf "  cert: %s\n" "$NAME-es-cert"
}


function wait_for_green() {
  type=$1
  object=$2
  set +e
  while true; do
    kubectl get -n monitoring $type $object | grep green
    if [ $? -eq 0 ]; then
      break
    fi
    sleep 5
  done
  set -e
}

function gen_certs() {
  CERTDIR=out/$CONFIG/elasticsearch-$NAME/certs
  mkdir -p $CERTDIR
  openssl req -x509 -sha256 -nodes -newkey rsa:4096 -days 365 -subj "/CN=$NAME-es-http" -addext "subjectAltName=DNS:$NAME-es-http.default.svc" -keyout $CERTDIR/tls.key -out $CERTDIR/tls.crt
  kubectl delete secret -n monitoring $NAME-es-cert || true
  kubectl create secret -n monitoring generic $NAME-es-cert --from-file=ca.crt=$CERTDIR/tls.crt --from-file=tls.crt=$CERTDIR/tls.crt --from-file=tls.key=$CERTDIR/tls.key
}

if [ -z "$OPTION" ]; then
  echo "$0 [init | install | getpassword | teardown | setup-index | create-yaml | install-exporter]"
else
  case $OPTION in
    init)
      create_yaml
      kubectl apply -f out/$CONFIG/elasticsearch-$NAME/templates/operator.yaml
      kubectl apply -n monitoring -f out/$CONFIG/elasticsearch-$NAME/templates/setup_mem.yaml
      sleep 5 # wait a bit before the operator spin up container
      kubectl wait -n elastic-system --for=condition=Ready pod elastic-operator-0 --timeout=15m
      gen_certs
      ;;
    gen-certs)
      gen_certs
      ;;
    install)
      create_yaml
      kubectl apply -n monitoring -f out/$CONFIG/elasticsearch-$NAME/templates/elasticsearch.yaml
      wait_for_green elasticsearch elasticsearch-$NAME
      kubectl apply -n monitoring -f out/$CONFIG/elasticsearch-$NAME/templates/kibana.yaml
      wait_for_green kibana kibana-$NAME
      kubectl apply -n monitoring -f out/$CONFIG/elasticsearch-$NAME/templates/es_ilb.yaml
      ;;
    install-exporter)
      IP=""
      get_ip
      PASSWD=`kubectl get secrets -n monitoring elasticsearch-$NAME-es-elastic-user '-o=jsonpath={.data.elastic}' |base64 --decode`
      helm repo add stable https://charts.helm.sh/stable
      helm template stable/elasticsearch-exporter -n monitoring --name-template $NAME -f out/$CONFIG/elasticsearch-$NAME/templates/exporter_values.yaml --set es.uri=https://elastic:$PASSWD@$IP:9200  --output-dir out/$CONFIG
      kubectl apply -n monitoring -f out/$CONFIG/elasticsearch-exporter/templates 
      ;;
    getendpoints)
      get_endpoints_yaml | tee out/$CONFIG/elasticsearch-$NAME/endpoints.yaml
      ;;
    teardown)
      kubectl delete -n monitoring es elasticsearch-$NAME
      kubectl delete -n monitoring kibana kibana-$NAME
      kubectl delete -n monitoring -f out/$CONFIG/elasticsearch-exporter/templates 
      # kubectl delete -n monitoring -f out/$CONFIG/elasticsearch-$NAME/templates/es_ilb.yaml
      ;;
    setup-index)
      if [ -z "$ELASTIC" ]; then
        ELASTIC=out/$CONFIG/elasticsearch-$NAME/endpoints.yaml
      fi

      if [[ $(yq -V) =~ "version 4" ]]; then
	    SCHEME=`yq e .elasticsearch.scheme $ELASTIC`
	    IP=`yq e .elasticsearch.hosts[0].host $ELASTIC`
	    PORT=`yq e .elasticsearch.hosts[0].port $ELASTIC`
	    USER=`yq e .elasticsearch.user $ELASTIC`
	    PASSWD=`yq e .elasticsearch.password $ELASTIC`
	  else
        SCHEME=`yq r $ELASTIC elasticsearch.scheme`
        IP=`yq r $ELASTIC elasticsearch.hosts[0].host`
        PORT=`yq r $ELASTIC elasticsearch.hosts[0].port`
        USER=`yq r $ELASTIC elasticsearch.user`
        PASSWD=`yq r $ELASTIC elasticsearch.password`
      fi

      # Step 1: Install the mappings
      # NOTE: mappings for internal and external clusters have diverged.
      # TBD: Should be converged soon after discussing with analytics team.
      curl -X PUT -k -u $USER:$PASSWD $SCHEME://$IP:$PORT/_template/${INDEX}_mapping -H "Content-Type: application/json; charset=utf-8" -d@index_templates/mapping_${INDEX}.json

      #Step 2: Install settings
      if [ -f "index_templates/settings/$CONFIG.json" ]; then   
        curl -X PUT -k -u $USER:$PASSWD $SCHEME://$IP:$PORT/_template/${INDEX}_setting -H "Content-Type: application/json; charset=utf-8" -d@index_templates/settings/${CONFIG}.json
      fi

      if [ -f "out/$CONFIG/elasticsearch-$NAME/templates/index_template_settings_fixed.json" ]; then   
        curl -X PUT -k -u $USER:$PASSWD $SCHEME://$IP:$PORT/_template/${INDEX}_setting -H "Content-Type: application/json; charset=utf-8" -d@out/$CONFIG/elasticsearch-$NAME/templates/index_template_settings_fixed.json
      fi

      if [ -f "out/$CONFIG/elasticsearch-$NAME/templates/critical_index_template_settings_fixed.json" ]; then   
        curl -X PUT -k -u $USER:$PASSWD $SCHEME://$IP:$PORT/_template/critical_${INDEX}_setting -H "Content-Type: application/json; charset=utf-8" -d@out/$CONFIG/elasticsearch-$NAME/templates/critical_index_template_settings_fixed.json
      fi
      ;;    
    create-yaml)
      create_yaml
      ;;
    test)
      wait_for_green elasticsearch elasticsearch-atscale
  esac
fi
