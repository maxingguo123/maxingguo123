CLUSTER=${CLUSTER:?}
EFK_DIR=$(dirname $(readlink -f $0))

if [ -f "$EFK_DIR/config/$CLUSTER.sh" ]; then
  source $EFK_DIR/config/$CLUSTER.sh
else
  USERNAME=${USERNAME:?}
  ELASTIC_IP=${ELASTIC_IP:?}
  ELASTIC_PORT=${ELASTIC_PORT:?}
fi

#USERNAME can be an array or string value
for USER in "${USERNAME[@]}"
do
  if [ "$USER" == "default" ]
  then
    MGMT_NS=mgmt
  else
    MGMT_NS=$USER-mgmt
  fi

  sed -e "s/REPLACE_WITH_ELASTIC_ADDRESS/$ELASTIC_IP/" -e "s/REPLACE_WITH_ELASTIC_PORT/$ELASTIC_PORT/" -e "s/CLUSTER_NOTSET/$CLUSTER/" -e "s/TEMPL_USERNAME/$USER/" -e "s/TEMPL_MGMT_NS/$MGMT_NS/" $EFK_DIR/fluentd-es-configmap.tpl > $EFK_DIR/fluentd-es-configmap-$USER.yaml 
  sed -e "s/REPLACE_WITH_ELASTIC_ADDRESS/$ELASTIC_IP/" -e "s/REPLACE_WITH_ELASTIC_PORT/$ELASTIC_PORT/" -e "s/CLUSTER_NOTSET/$CLUSTER/" -e "s/TEMPL_USERNAME/$USER/" -e "s/TEMPL_MGMT_NS/$MGMT_NS/" $EFK_DIR/fluentd-es-ds.tpl > $EFK_DIR/fluentd-es-ds-$USER.yaml 
done
