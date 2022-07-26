#!/bin/bash

if [[ "$NODES" == "NA" ]]
then
echo "Nothing to do, nodes: $NODES"
fi

echo "Setting KUBECONFIG for cluster: $CLUSTER"
export KUBECONFIG=/srv/kube/config.icx-1
if [[ "$CLUSTER" == "gdc-1" ]]
then
export KUBECONFIG=/srv/kube/config.gdc-1
elif [[ "$CLUSTER" == "opus" ]]
then
export KUBECONFIG=/srv/kube/config.opus
fi
echo "Config: $KUBECONFIG"
if [[ "$NODEOWNER" == "NA" ]]
then
kubectl --insecure-skip-tls-verify label node $NODES $REMOVE_LABEL $ADD_LABEL --overwrite
else
kubectl --insecure-skip-tls-verify label node $NODES $REMOVE_LABEL $ADD_LABEL nodeowner=$NODEOWNER --overwrite
fi
kubectl --insecure-skip-tls-verify get node $NODES --show-labels

echo "nodes: ${NODES// /,}"

case $NODEOWNER in
   "default") export REMOVE_NODES=${NODES// /,}
   ;;
   "ive") export IVE_NODES=${NODES// /,}
   ;;
   "piv") export PIV_NODES=${NODES// /,}
   ;;
   "oss") export OSS_NODES=${NODES// /,}
   ;;
   "cdc") export CDC_NODES=${NODES// /,}
   ;;
   "NA") exit
   ;;
   *) echo "Sorry, the nodeowner $NODEOWNER is not in the list!"
   exit
   ;;
esac
echo "Changing machine owners: "
python configmap_cleaner.py --cluster=$CLUSTER
./apply_machine_owners.sh $KUBECONFIG $CLUSTER
git commit -asm 'MachineOwner Systems Update.'

