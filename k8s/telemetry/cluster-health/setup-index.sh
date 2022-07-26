set -e

INDEX=${INDEX:=clusterhealth}
CONFIG=${CONFIG:?Required to set $CONFIG}

if [ -z "$ELASTIC" ]; then
    ELASTIC=../elasticsearch/endpoints/$CONFIG.yaml
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

if [[ "$CONFIG" == "gdc" ]]; then
    curl -X PUT $SCHEME://$IP:$PORT/_template/${INDEX}_mapping -H "Content-Type: application/json; charset=utf-8" -d@index-templates/mapping_${INDEX}-gdc.json
else
    curl -X PUT -k -u $USER:$PASSWD $SCHEME://$IP:$PORT/_template/${INDEX}_mapping -H "Content-Type: application/json; charset=utf-8" -d@index-templates/mapping_${INDEX}.json

    if [ -f "templates/index_template_settings_fixed.json" ]; then
        curl -X PUT -k -u $USER:$PASSWD $SCHEME://$IP:$PORT/_template/${INDEX}_setting -H "Content-Type: application/json; charset=utf-8" -d@templates/index_template_settings_fixed.json
    fi
fi
