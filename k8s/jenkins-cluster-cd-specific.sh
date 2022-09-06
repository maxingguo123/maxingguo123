#!/bin/bash

: ${KUBECTL_ARGS:=""}
: ${NS:="default"}
: ${REGISTRY:="pnp-harbor.sh.intel.com"}
: ${RUN_AGGRESSOR:=false}
: ${AGGRESSOR_CONFIG:=""}
: ${AGGRESSOR_SCRIPT:=""}
: ${REPLICAS:=""}
: ${SANDSTONE_RUN_COMPLETE:="sandstone_run_completed.yaml"}
: ${LOGS:="FALSE"}


if [ -z ${1-} ]; then
  TIME="300"
else
  TIME=${1}
fi
: ${AGGRESSOR_RUNTIME:=${TIME}}

if [ -z "$ATSCALE_RUNID" ]
then
    export ATSCALE_RUNID=run-`cat /dev/urandom | tr -dc a-z0-9 | fold -w 6 | head -1`
fi

function get_sandstone_logs() {
  echo
  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get nodes -o wide -l=$JENKINS_NODE_LABEL
  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get po -o wide -n ${NS} -l name=$JENKINS_TEST_LABEL
  if [[ "$LOGS" == "TRUE" ]]
  then
  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get events --all-namespaces --field-selector reason="Hardware Error"
  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get events --all-namespaces --field-selector reason="Hardware Error" -o json
  PODS=$(kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get pods -n ${NS} | grep $1 | awk '{print $1}')
  for POD in ${PODS}; do
    echo "POD: "${POD}
    kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify logs -n ${NS} ${POD} --all-containers=true
  done
  fi
  echo
}

# We have to wait till the enviornment is clean. There is no point running them in parallel
function sandstone_flush() {
  count=0

    while true; do
      kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify delete ds -n ${NS} --all
      if [ $? -eq 0 ]; then
        break
      fi
      count=$((count+1))
      echo "Retry to cleanup test enviornment $count"
      date
    done
}

function sandstone_run_complete() {
   curl -O https://raw.githubusercontent.com/maxingguo123/maxingguo123/main/k8s/$SANDSTONE_RUN_COMPLETE

   sed \
    -e "s/REGISTRY/${REGISTRY}/" \
    -e "s/NAMESPACE/$NS/" \
    -e "s/SANDSTONE_NAME/$JENKINS_TEST_LABEL/" \
    -e "s/SANDSTONE_NODE_LABEL/$JENKINS_NODE_LABEL/" \
    "$SANDSTONE_RUN_COMPLETE" | kubectl ${KUBECTL_ARGS} apply --insecure-skip-tls-verify -f -

   if [ $? -eq 0 ]; then
    sleep 60 # Wait for run completion cleanup. If only this can be done using a kubernetes job!

    sed \
    -e "s/REGISTRY/${REGISTRY}/" \
    -e "s/NAMESPACE/$NS/" \
    -e "s/SANDSTONE_NAME/$JENKINS_TEST_LABEL/" \
    -e "s/SANDSTONE_NODE_LABEL/$JENKINS_NODE_LABEL/" \
     "$SANDSTONE_RUN_COMPLETE" | kubectl ${KUBECTL_ARGS} delete --insecure-skip-tls-verify -f -
   fi
}

function sandstone_delete() {
  loopcount=$2
  count=0
  ret=0
  OUT=$(sed \
    -e "s/SANDSTONE_BIN_PATH/$JENKINS_TEST_BINARY/" \
    -e "s/SANDSTONE_NAME/$JENKINS_TEST_LABEL/" \
    -e "s/SANDSTONE_NODE_LABEL/$JENKINS_NODE_LABEL/" \
    -e "s/SANDSTONE_TEST_ARGS/$JENKINS_TEST_ARGS/" \
    -e "s/DOCKER_TAG/$JENKINS_TEST_TAG/" \
    -e "s/NAMESPACE/$NS/" \
    -e "s/REPLICAS/${REPLICAS}/" \
    -e "s/RUN_DRAGON_ARG/${RUN_DRAGON_ARG}/" \
    -e "s/DRAGON_ARGS_ARG/${DRAGON_ARGS_ARG}/" \
    -e "s/DRAGON_TYPE_ARG/${DRAGON_TYPE_ARG}/" \
    -e "s/EXTRA_ARGS_ARG/${EXTRA_ARGS_ARG}/" \
    -e "s/GB_USER_ARG/${GB_USER_ARG}/" \
    -e "s/GB_KEY_ARG/${GB_KEY_ARG}/" \
    -e "s/GB_ITERATIONS_ARG/${GB_ITERATIONS_ARG}/" \
    -e "s/REGISTRY/${REGISTRY}/" \
    -e "s/INIT_MSR_SET_VAL/$INIT_MSR_SET_VAL/" \
    -e "s/INIT_MSR_CPU_VAL/$INIT_MSR_CPU_VAL/" \
    -e "s/ATSCALE_RUNID/$ATSCALE_RUNID/" \
    -e "s/ATSCALE_PIPELINE/$JOB_BASE_NAME/" \
    -e "s/ATSCALE_BUILD_TIMESTAMP/$BUILD_TIMESTAMP/" \
    -e "s/CEPH_VOL_YAML//" \
    -e "s/CEPH_VOLMOUNT_YAML//" \
    "$SANDSTONE_DEPLOYMENT" | kubectl ${KUBECTL_ARGS} delete --insecure-skip-tls-verify -f - 2>&1)
  echo ${OUT}

  if [ $? -ne 0 ] && [[ ! "${OUT}" =~ "not found" ]]; then
    while true; do
      # For good measure just delete the workload whether it is complete or not!
      OUT=$(kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify delete ds -n ${NS} ${JENKINS_TEST_LABEL} 2>&1)
      if [ $? -eq 0] || [[ "${OUT}" =~ "not found" ]]; then
        break
      fi
      count=$((count+1))
      echo "Waiting $count (of $loopcount)"
      sleep 10
      if [ $count -eq "$loopcount" ]; then
        echo "Unable to delete workload ${JENKINS_TEST_LABEL}"
        return 2
      fi
    done
  fi

  if [[ -n "$CEPH_ROOTPATH" ]]; then
    delete_pvc
    delete_pv
  fi

  sandstone_run_complete
}

function sandstone_test() {
  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get nodes -o wide -l=$JENKINS_NODE_LABEL
  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get po -o wide -n ${NS} -l name=$JENKINS_TEST_LABEL

  if [[ -n "$CEPH_ROOTPATH" ]]; then
    create_pv
    create_pvc
  fi
  date

  sed \
    -e "s/SANDSTONE_BIN_PATH/$JENKINS_TEST_BINARY/" \
    -e "s/SANDSTONE_NAME/$JENKINS_TEST_LABEL/" \
    -e "s/SANDSTONE_NODE_LABEL/$JENKINS_NODE_LABEL/" \
    -e "s/SANDSTONE_TEST_ARGS/$JENKINS_TEST_ARGS/" \
    -e "s/DOCKER_TAG/$JENKINS_TEST_TAG/" \
    -e "s/NAMESPACE/$NS/" \
    -e "s/REPLICAS/${REPLICAS}/" \
    -e "s/RUN_DRAGON_ARG/${RUN_DRAGON_ARG}/" \
    -e "s/DRAGON_ARGS_ARG/${DRAGON_ARGS_ARG}/" \
    -e "s/DRAGON_TYPE_ARG/${DRAGON_TYPE_ARG}/" \
    -e "s/EXTRA_ARGS_ARG/${EXTRA_ARGS_ARG}/" \
    -e "s/GB_USER_ARG/${GB_USER_ARG}/" \
    -e "s/GB_KEY_ARG/${GB_KEY_ARG}/" \
    -e "s/GB_ITERATIONS_ARG/${GB_ITERATIONS_ARG}/" \
    -e "s/REGISTRY/${REGISTRY}/" \
    -e "s/INIT_MSR_SET_VAL/$INIT_MSR_SET_VAL/" \
    -e "s/INIT_MSR_CPU_VAL/$INIT_MSR_CPU_VAL/" \
    -e "s/ATSCALE_RUNID/$ATSCALE_RUNID/" \
    -e "s/ATSCALE_PIPELINE/$JOB_BASE_NAME/" \
    -e "s/ATSCALE_BUILD_TIMESTAMP/$BUILD_TIMESTAMP/" \
    -e "s/CEPH_VOL_YAML/$(build_vol_yaml)/" \
    -e "s#CEPH_VOLMOUNT_YAML#$(build_volmount_yaml)#" \
    "$SANDSTONE_DEPLOYMENT" | kubectl ${KUBECTL_ARGS} apply --insecure-skip-tls-verify -f -
  RES=$?

  # We have setup scripts/run-once.sh to run for 300s
  # Kubernetes bug workaround
  date
  if [ ${RES} -eq 0 ]; then
    END=$((SECONDS+${TIME}))
    if [[ "${RUN_AGGRESSOR}" == true ]] && [[ -f "${AGGRESSOR_CONFIG}" ]]; then
      AGGRESSOR_CONFIG=${AGGRESSOR_CONFIG} ${AGGRESSOR_SCRIPT} ${AGGRESSOR_RUNTIME}
    fi
    while [ ${SECONDS} -le ${END} ]; do
        sleep 30
    done
  fi

  kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get -n ${NS} ds/$JENKINS_TEST_LABEL
  date

  if [ $? -ne 0 ]; then
    kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify get po -o wide -n ${NS}
    get_sandstone_logs $JENKINS_TEST_LABEL
    echo "PIPELINE-TEST-FAILED"
    return 1
  fi

  get_sandstone_logs $JENKINS_TEST_LABEL
  return 0
}
# PV
function build_pv(){
cat<<EOF
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: "${NS}-${JENKINS_TEST_LABEL}"
  spec:
    claimRef:
      namespace: "$NS"
      name: "${NS}-${JENKINS_TEST_LABEL}"
    storageClassName: ""
    accessModes:
    - ReadOnlyMany
    capacity:
      storage: "$CEPH_SIZE"
    csi:
      driver: cephfs.csi.ceph.com
      nodeStageSecretRef:
        name: csi-cephfs-secret
        namespace: jascott1
      volumeAttributes:
        "clusterID": "$CEPH_CLUSTERID"
        "fsName": "cephfs"
        "staticVolume": "true"
        "rootPath": "$CEPH_ROOTPATH"
      # volumeHandle can be anything, need not to be same
      # as PV name or volume name. keeping same for brevity
      volumeHandle: "${NS}-${JENKINS_TEST_LABEL}"
    persistentVolumeReclaimPolicy: Retain
    volumeMode: Filesystem
EOF
}
function create_pv(){
  PV=$(build_pv)
  echo "$PV" | kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify apply -f -
}
function delete_pv(){
  PV=$(build_pv)
  echo "$PV" | kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify delete -f -
}
# PVC
function build_pvc(){
cat<<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: "${NS}-${JENKINS_TEST_LABEL}"
    namespace: "$NS"
  spec:
    accessModes:
    # ReadWriteMany is only supported for Block PVC
    - ReadOnlyMany
    resources:
      requests:
        storage: $CEPH_SIZE
    volumeMode: Filesystem
    # volumeName should be same as PV name
    volumeName: "${NS}-${JENKINS_TEST_LABEL}"
EOF
}
function create_pvc(){
  PVC=$(build_pvc)
  echo "$PVC" | kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify apply -f -
}
function delete_pvc(){
  PVC=$(build_pvc)
  echo "$PVC" | kubectl ${KUBECTL_ARGS} --insecure-skip-tls-verify delete -f -
}
function build_vol_yaml(){

if [[ -n "$CEPH_ROOTPATH" ]]; then
cat<<EOF
- name: ceph-mount\\
          persistentVolumeClaim:\\
            claimName: "${NS}-${JENKINS_TEST_LABEL}"
EOF
fi
}
function build_volmount_yaml(){
if [[ -n "$CEPH_ROOTPATH" ]]; then
cat<<EOF
- name: ceph-mount\\
            mountPath: "$CEPH_MOUNT_TARGET"\\
            subPath: "$CEPH_MOUNT_SOURCE"
EOF
fi
}
# Get the latest manifest and loop script
# There is a small possibility that the jenkins-latest does not match but we ignore this for now
#curl -O http://kojiclear.jf.intel.com/cgit/bdx/sandstone/plain/k8s/"$SANDSTONE_DEPLOYMENT"

date
#We are in non stop mode. Delete any existing run
#First grab any logs
#This is needed as the previous run could have failed due to network issues
#The next test that runs when the network recovers should grab data from last run
#get_sandstone_logs $JENKINS_TEST_LABEL
#date
sandstone_flush

date
sandstone_test

date
# Wait for upto two hours. This should never happen unless we loose network
# connectivity to the cluster from jekins
sandstone_delete $JENKINS_TEST_LABEL 24

date

echo "PIPELINE-TEST-PASSED"

