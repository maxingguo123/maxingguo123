#!/bin/bash
set -e
# Set cluster based on argument (path to kubeconfig file)
export KUBECONFIG="$1"
export CLUSTER="$2"
# Apply new machine ownersi
RUN_PATH=`pwd`
FILE='machine-owners-icx.yaml'
if [[ "$CLUSTER" == "gdc-1" ]]
then
export FILE='machine-owners-purley.yaml'
elif [[ "$CLUSTER" == "opus" ]]
then
export FILE='machine-owners-opus.yaml'
fi

kubectl --insecure-skip-tls-verify apply -f $RUN_PATH/$FILE

# Restart the monitoring solution
kubectl --insecure-skip-tls-verify get po -A -owide | grep hook | awk '{print $1, $2}' | while read line; do kubectl --insecure-skip-tls-verify delete po -n $line  --grace-period=0 --force; done
