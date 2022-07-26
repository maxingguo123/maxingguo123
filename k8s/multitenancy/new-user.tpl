---
apiVersion: v1
kind: Namespace
metadata:
  name: NEWUSERNS
  annotations:
    scheduler.alpha.kubernetes.io/node-selector: nodeowner=NEWUSER
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: NEWUSERNS
  name: NEWUSER-manager
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["deployments", "replicasets", "pods", "pods/log", "daemonsets", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] # You can also use ["*"]
- apiGroups: ["kubeflow.org"]
  resources: ["mpijobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] # You can also use ["*"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "create", "delete", "deletecollection", "patch", "update", "watch"]
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: NEWUSER-cluster-manager
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: NEWUSER-manager-binding
  namespace: NEWUSERNS
subjects:
- kind: User
  name: NEWUSER
  apiGroup: ""
roleRef:
  kind: Role
  name: NEWUSER-manager
  apiGroup: ""
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: NEWUSER-cluster-manager-binding
subjects:
- kind: User
  name: NEWUSER
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: NEWUSER-cluster-manager
  apiGroup: ""
