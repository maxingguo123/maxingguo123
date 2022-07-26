#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# will need to update this key for any new systems, see "Configuration/API Keys" in the grafana GUI
KEY="eyJrIjoieTRkeWNIWmNiRDd0UWdvZ2tZZDVCTXBXQzhieGUydlUiLCJuIjoiaW1wb3J0LWFwaSIsImlkIjoxfQ=="
HOST="http://localhost:3000"

if [ ! -d $SCRIPT_DIR/dashboards ] ; then
    echo "directory ./dashboards does not exist" 
fi

# this var is used in the following function but is set in the for loop below
content=""
get_dash() {
cat << EOF 
{
  "dashboard": 
  $content, 
  "inputs": [], 
  "overwrite": false
}
EOF
}

for dash in $SCRIPT_DIR/dashboards/*.json; do
   echo "uploading $dash"
   content=$(cat $dash | sed '0,/\ \ \"id\".*/s//\ \ \"id\": null,/')
   curl  -k -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -H "Accept: application/json" -X POST $HOST/api/dashboards/import --data "$(get_dash)"
done
