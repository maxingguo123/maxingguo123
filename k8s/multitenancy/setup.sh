set -e

OPTION=$1
export CONFIG=${CONFIG:?Required to set $CONFIG (e.g. whitley, flex, opus etc.)}

function create_yaml() {
      ./generate_certs.sh --secret labeling-validator-webhook-certs --namespace mgmt --service labeling-validator-webhook --webhook-kind ValidatingWebhookConfiguration --webhook labeling-validator-webhook
}

if [ -z "$OPTION" ]; then
  echo "$0 [install | teardown | create-yaml]"
else
  case $OPTION in
    install)
      create_yaml
      kubectl apply -f out/$CONFIG/
      ;;
    teardown)
      kubectl delete -f out/$CONFIG/
      kubectl delete csr/labeling-validator-webhook.mgmt
      ;;
    create-yaml)
      create_yaml
      ;;
  esac
fi
