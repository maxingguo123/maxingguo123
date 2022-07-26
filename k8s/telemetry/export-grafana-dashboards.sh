#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# will need to update this key for any new systems, see "Configuration/API Keys" in the grafana GUI
KEY="eyJrIjoiUGRzRGk5bHRCM3R4Um85NERNelVuZVJSeUI1bVcwcmkiLCJuIjoiZGFzaC1leHBvcnQiLCJpZCI6MX0="
HOST="http://localhost:3000"

if [ ! -d $SCRIPT_DIR/dashboards ] ; then
    mkdir -p $SCRIPT_DIR/dashboards
fi

while read uid title; do
    file=$(sed s/\ /_/g <<<${title})
    curl -k -H "Authorization: Bearer $KEY" $HOST/api/dashboards/uid/${uid} | jq '.dashboard' | tee > $SCRIPT_DIR/dashboards/${file}.json
done < <(curl -k -H "Authorization: Bearer $KEY" $HOST/api/search\?query\=\& | jq -r '.[] | "\(.uid) \(.title)"')
