set -e

OPTION=$1
CONFIG=${CONFIG:?Required to set $CONFIG}
KAFKA=${KAFKA:?kafka endpoints yaml file}
NAME=`yq r values/$CONFIG.yaml name`

function create_conf() {
  mkdir -p /etc/atscale/fluentd/$NAME 
  mkdir -p out/$CONFIG
  cat $KAFKA values/$CONFIG.yaml | ../../bin/gotpl templates/fluentd.conf.tpl | tee out/$CONFIG/fluentd.conf > /etc/atscale/fluentd/$NAME/fluentd.conf
  cat $KAFKA values/$CONFIG.yaml | ../../bin/gotpl templates/atscale.fluentd.service.tpl| tee out/$CONFIG/atscale.$NAME.fluentd.service > /etc/systemd/system/atscale.$NAME.fluentd.service
}

if [ -z "$OPTION" ]; then
	echo "$0 [install | teardown | create-yaml]"
else
	case $OPTION in
		install)
      create_conf
      systemctl daemon-reload
      systemctl start atscale.$NAME.fluentd.service
      systemctl enable atscale.$NAME.fluentd.service
			;;
		teardown)
      systemctl stop atscale.$NAME.fluentd.service || true
      systemctl disable atscale.$NAME.fluentd.service || true
      rm -f /etc/systemd/system/atscale.$NAME.fluentd.service 
      rm -rf /etc/atscale
			;;
    create-conf)
      create_conf
      ;;
	esac
fi
