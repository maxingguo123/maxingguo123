
#!/bin/bash
set -e
set -x

export http_proxy=http://10.1.192.48:911
export https_proxy=http://10.1.192.48:912

OPTION=$1
if [ -z "$OPTION" ]; then
        echo "$0 [install | teardown]"
else
        case $OPTION in
                install)
      if [ `which ctr ` ]
      then
        ctr_val=`which ctr`
        sed -i "s=ctr=$ctr_val=g" clusterscope.conf
      else
        echo "containerd not installed"
        exit
      fi
      mkdir_val=`which mkdir`
      sed -i "s=mkdir=$mkdir_val=g" clusterscope.conf
      if [ ! -f /usr/bin/jq ]
      then
        wget -O /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
        chmod +x /usr/bin/jq
      fi
      if [ `hostname | grep fl30l` ]
      then
        #flex node so have to change clusterscope api url
         sed -i "s=ive-infra04.deacluster.intel.com:5000=api.clusterscope.ingress.fl30lcent1.deacluster.intel.com=g" cscope_service.sh
      fi
      cp clusterscope.conf /etc/systemd/system/atscale.clusterscope.service
      cp cscope_service.sh /usr/local/bin/cscope_service.sh
      chmod +x /usr/local/bin/cscope_service.sh
      systemctl daemon-reload
      systemctl start atscale.clusterscope.service
      systemctl enable atscale.clusterscope.service
                        ;;
                teardown)
      systemctl stop atscale.clusterscope.service || true
      systemctl disable atscale.clusterscope.service || true
      rm -f /etc/systemd/system/atscale.clusterscope.service
      systemctl daemon-reload || true
      systemctl reset-failed || true
        esac
fi
