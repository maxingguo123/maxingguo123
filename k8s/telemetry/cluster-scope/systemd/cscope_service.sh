#!/usr/bin/bash
#set -x
svc_name="atscale.clusterscope.service"

OPTION=$1
if [ -z "$OPTION" ]; then
        echo "$0 [start | stop]"
else
        case $OPTION in
                start)
      if [ ! `which ctr ` ]
      then
        echo "Error: containerd not installed"
        exit
      fi

      #jq is required
      if [ ! -f /usr/bin/jq ]
      then
        wget -O /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
        chmod +x /usr/bin/jq
      fi
      #Cleanup any existing copy of the service
      ctr task rm -f $svc_name 2>/dev/null
      ctr container rm $svc_name 2>/dev/null

      #pull the latest copy of the container
      ctr images pull prt-registry.sova.intel.com/cluster-scope:latest 2>/dev/null

      mkdir -p /var/log/atscale

      #Time to start the container
      ctr run \
      --privileged \
      --net-host \
      --env="HOST=$HOSTNAME" \
      --env="HOST_IP=`hostname -I | awk '{print $1}'`" \
      --env="CLUSTER_METADATA=/hostroot/var/log/atscale/cscope-metadata.ndjson" \
      --env="LOCATION=`echo $HOSTNAME| cut -d. -f2`" \
      --env="ROOT_URL=ive-infra04.deacluster.intel.com:5000/api/node/metadata?name=" \
      --mount type=bind,src=/,dst=/hostroot,options=rbind \
      prt-registry.sova.intel.com/cluster-scope:latest $svc_name /run.sh
                        ;;
                stop)
      ctr task rm -f $svc_name 2>/dev/null
      ctr container rm $svc_name 2>/dev/null
        esac
fi
