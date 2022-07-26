DATE=$1

if [ -n "$DATE" ]; then
  sed "s/DATE/${DATE}/" reindex.json > /tmp/reindex.json
  curl http://10.219.23.201:9200/_reindex?slices=8 -XPOST -H "Content-Type: application/json" -d @/tmp/reindex.json
  curl -XPOST http://10.219.23.201:9200/qpool-${DATE}/_close
fi
