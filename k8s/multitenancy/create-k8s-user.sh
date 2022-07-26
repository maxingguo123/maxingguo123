#!/bin/bash

set -o nounset
set -o errexit

: ${NEWUSER:=""}
: ${NEWUSERNS:=${NEWUSER}}
: ${CLUSTER:="kubernetes"}
: ${READONLY:=false}
ALLCONFIG=""

if ${READONLY}; then
	NEWUSER=readonlyuser
fi

if [ -z "${NEWUSER}" ]; then
	echo "Need new user name"
	exit 1
fi

function create_user()
{
  sudo -E openssl genrsa -out /etc/kubernetes/pki/${NEWUSER}.key 4096
  sudo chmod a+r /etc/kubernetes/pki/${NEWUSER}*
  sudo -E openssl req -new -key /etc/kubernetes/pki/${NEWUSER}.key -out ${NEWUSER}.csr -subj "/CN=${NEWUSER}/O=intel"
  sudo -E openssl x509 -req -in ${NEWUSER}.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out /etc/kubernetes/pki/${NEWUSER}.crt -days 500000
  sudo chmod a+r /etc/kubernetes/pki/${NEWUSER}*
  # We are done with the csr file. Time to dump it.
  sudo -E rm ${NEWUSER}.csr
  kubectl config set-credentials ${NEWUSER} --client-certificate=/etc/kubernetes/pki/${NEWUSER}.crt --client-key=/etc/kubernetes/pki/${NEWUSER}.key
}

create_ns()
{
  for ns in $(echo ${NEWUSERNS} | sed -e 's/,/\ /g'); do
  	kubectl config set-context ${ns}-context --cluster=${CLUSTER} --namespace=${ns} --user=${NEWUSER}
  	sed -e "s/NEWUSERNS/${ns}/g" -e "s/NEWUSER/${NEWUSER}/g" new-user.tpl | kubectl apply -f -
  	kubectl config --context=${ns}-context --cluster=${CLUSTER} view --raw --flatten --minify > ${ns}.config
  	ALLCONFIG+="${ns}.config:"
  done

  # Generate unified config that the user can use to control all the contexts and namespaces
  KUBECONFIG=${ALLCONFIG} kubectl config view --merge --flatten > ${NEWUSER}.kubeconfig

  # Remove all indivudual configs to avoid confusion
  for ns in $(echo ${NEWUSERNS} | sed -e 's/,/\ /g'); do
  	rm ${ns}.config
  done
}

create_readonly_config()
{
  kubectl config set-context readonlyuser-context --cluster=${CLUSTER} --user=${NEWUSER}
  kubectl apply -f readonly-user.tpl
  kubectl config --context=readonlyuser-context --cluster=${CLUSTER} view --raw --flatten --minify > readonlyuser.config
}

if [ ! -f /etc/kubernetes/pki/ca.crt ]; then
  echo "Need to run this script on the master node."
  exit 1
fi

if [ ! -f /etc/kubernetes/pki/${NEWUSER}.crt ]; then
  create_user
fi
if ${READONLY}; then
  create_readonly_config
else
  create_ns
fi
