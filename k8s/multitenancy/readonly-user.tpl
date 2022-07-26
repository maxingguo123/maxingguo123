---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: readonlyuser
rules:
- apiGroups: ["*"]
  resources: ["*",  "pods/log"]
  verbs: ["get", "list", "watch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: readonlyuser
subjects:
- kind: User
  name: readonlyuser
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: readonlyuser
  apiGroup: ""
