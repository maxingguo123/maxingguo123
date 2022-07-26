# Soft multitenancy in Internal Cluster
The goal of this document is to explain how multitenancy is implemented in the
internal clusters and how a new set of users can be included into the cluster.

* [Goals](#goals)
* [Purpose](#purpose)
* [How to deploy](#how-to-deploy)
* [New Users](#new-users)
* [ReadOnly User](#readonly-user)

## Goals
The goal of this effort is the have all machines of a certain class be part of
a single testing cluster within Intel, but have the sub-teams run their
indivudual pipelines/tests on their systems. A user is given full control on
what tests run on their systems and they are allowed to sub-segment their
cluster using labels and run content on various namespaces owned by them.

The advantages being
* Single telemetry end-point for all content related to a class of machines.
* All systems get updates uniformly (microcode, etc).
* Machines can be moved in and out of the main testing pipeline with absolute ease.
* Allows teams to test their content in container format prior to pushing it into the main pipeline.

## Purpose
The purpose of this Cluster Policy Controller (which consists of *namespace*,
*namespace policy*, *pod policy* and a *policy webhook*) and controls are as belows.
* Allow deployment of tests by a user on their machines in namespaces owned by them.
* Allow user to label nodes they own aiding them in sub-segmenting their cluster to run different tests on each of them.
* Deny the user from labeling nodes that are not owned by them.
* Prevent user from removing the primary label that identifies their nodes. `<USER>node`.
* Prevent users from removing machines from the cluster.

## How to deploy
1. Modify your cluster to make sure you have `PodNodeSelector` admission plugin
   is enabled. This plugin allows the admin to set a mandatory label to
   identify nodes that are owned by an user. Any content deployed by the user
   in their namespaces can only run on machines labeled with this value.

  * Login to k8s master node.
  * `grep PodNodeSelector /etc/kubernetes/manifests/kube-apiserver.yaml`
  * Make sure that string exists. If not, edit the file and make sure it resembles the line below.
      `- --enable-admission-plugins=NodeRestriction,PodNodeSelector`
  * You will notice that kube-apiserver container restarts itself after you save changes to the file.
2. Create a configmap named `machine-owners-list` in `mgmt` namespace which
   creates a data file named `owner_file.yaml` which contains the owner and the
   list of machines they own.

   **NOTE: All our live clusters' configmaps are located in a top level folder
   named `machine-owners`. Verify one does not exist before you create a new
   one.**

   Below is a very good example of how the configmap
   should be created.

  ```yaml
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: machine-owners-list
    namespace: mgmt
  data:
    owner_file.yaml: |-
      ive:
        clr-02:
        clr-03:
  ```
3. Apply all the yamls in this folder. The do the below things.
  * `machine-owners-list.yaml`: Configmap that contains the mapping of machine owners to user account.
  * `webhook-certs.yaml`: Create certificates for the webhook that controls machine, owner mapping.
  * `webhook-registration.yaml`: Registers webhook as a validating webhook in the cluster.
  * `webhook.yaml`: Actual webhook deployment which maps the configmap and runs validator.

  ```bash
  kubectl apply -f k8s/multitenancy/
  ```

## New Users
The script `create-k8s-user.sh` will help you create the new user and namespaces that they can use to run their systems.
You will need two things. user account name, namespaces you wish to create.
for eg: to create user `ive` and namespaces `ive,ive-1,ive-2` you will need to do the following.
1. Login to k8s master node. **THIS HAS TO BE RUN ON THE MASTER NODE**
2. Run the below commands.
  ```bash
  curl -OL https://gitlab.devtools.intel.com/sandstone/cluster-infra/-/raw/master/k8s/multitenancy/new-user.tpl
  curl -OL https://gitlab.devtools.intel.com/sandstone/cluster-infra/-/raw/master/k8s/multitenancy/create-k8s-user.sh
  chmod +x create-k8s-user.sh
  NEWUSER=ive NEWUSERNS=ive,ive-1,ive-2 ./create-k8s-user.sh
  ```
3. Copy the configfile, `ive.kubeconfig` in this case and share it with the respective team.
4. Get a list of machines the team owns.
5. Add the user and machines list to the configmap defined in the previous section.
6. Apply configmap
7. Add nodes to the cluster.
8. Apply label nodeowner=<USER> to all the machines. In this case, it will be `nodeowner=ive`.

## ReadOnly User
We create a readonly user whose credentials would be used to provide all our cluster users a view-only access into the cluster using k9s and ttyd. The script will create a user with the name `readonlyuser`
```bash
  READONLY=true ./create-k8s-user.sh
```

# Troubleshooting New User

## Denied labeling when should succeed

**Symptom:**  

You are using/testing a restriced kubeconfig. You attempt to test label a node and the operation fails when it should succeed. You see an error simliar to:

```
# apply label
kubectl label node r061s001.fl30lse001 myuser-test=true
# error denying operation
Error from server: admission webhook "labeling-validator-webhook.mgmt.xyz" denied the request: myuser cannot apply labels that does not begin with myuser
```

**Solution:**  

Examine the node to ensure it does not have any other labels that do not start with the new user's name. If those labels exist, remove them.

NOTE: Do NOT remove any kubernetes labels, nodeowner or nodetype labels.

```
# show labels on node in question
kubectl get node --show-labels  <your node>
```

In below example, the label "cdc=true" is not prefixed with our user's name "myuser", so the request is denied.

```
beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,cdc=true,johntell=true,kubernetes.io/arch=amd64,kubernetes.io/hostname=r061s001.fl30lse001,kubernetes.io/os=linux,nodeowner=myuser
```

Remove the extra label that is causing the problem:

```
kubectl label node <your node> cdc-
```

**Background:**  

This multi-tenancy mechanism we use whitelists the "kubernetes.*" and "nodeowner" labels but expects other labels to start with our user's name. The 
information available to the validation function is limited to the incoming labels. It sees that a label (e.g. "cdc") does not start with the owning user's name ("myuser") and denies
the request. 




Now all the machines are in the cluster and the user can use their config to control the content that runs on the systems.

# YAML and Certificate Generation

The webhook YAML files require valid certificate to be embeded in base64. 


The `setup.sh` script will create new versions of the webhook YAML files, TLS key and cert in the output dir ("./out/$CONFIG").

```
CONFIG=whitley ./setup.sh create-yaml - only create yaml in the out/$CONFIG directory
CONFIG=whitley ./setup.sh install - create-yaml and install it to k8s
CONFIG=whitley ./setup.sh teardown - delete the objects from k8s using out/$CONFIG
```

NOTE: Certificates are signed in-cluster and are currently limited to fixed epiration of one year. This expiration time can be set globally with an experimental flag but we have not altered it. 

## Background
The script generates a private key and issues a Certificate Signing Request to k8s. The script approves the request and the returned cert and original key are added to the YAML files as necessary.

