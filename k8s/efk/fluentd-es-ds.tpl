apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd-es-TEMPL_USERNAME
  namespace: TEMPL_MGMT_NS
  labels:
    k8s-app: fluentd-es
    subcluster: TEMPL_USERNAME
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fluentd-es-TEMPL_USERNAME
  labels:
    k8s-app: fluentd-es
    subcluster: TEMPL_USERNAME
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
rules:
- apiGroups:
  - ""
  resources:
  - "namespaces"
  - "pods"
  verbs:
  - "get"
  - "watch"
  - "list"
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fluentd-es-TEMPL_USERNAME
  labels:
    k8s-app: fluentd-es
    subcluster: TEMPL_USERNAME
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
subjects:
- kind: ServiceAccount
  name: fluentd-es-TEMPL_USERNAME
  namespace: TEMPL_MGMT_NS
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: fluentd-es-TEMPL_USERNAME
  apiGroup: ""
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-es-v2.2.1-TEMPL_USERNAME
  namespace: TEMPL_MGMT_NS
  labels:
    k8s-app: fluentd-es
    subcluster: TEMPL_USERNAME
    version: v2.2.1
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    matchLabels:
      k8s-app: fluentd-es
      subcluster: TEMPL_USERNAME
      version: v2.2.1
  template:
    metadata:
      labels:
        k8s-app: fluentd-es
        subcluster: TEMPL_USERNAME
        kubernetes.io/cluster-service: "true"
        version: v2.2.1
      # This annotation ensures that fluentd does not get evicted if the node
      # supports critical pod annotation based priority scheme.
      # Note that this does not guarantee admission on the nodes (#40573).
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
        seccomp.security.alpha.kubernetes.io/pod: 'docker/default'
    spec:
      nodeSelector:
        nodeowner: TEMPL_USERNAME
      # Removing priority class to let the pods run in *-mgmt namespace instead of kube-system
      # priorityClassName: system-node-critical
      serviceAccountName: fluentd-es-TEMPL_USERNAME
      containers:
      - name: fluentd-es
        #image: k8s.gcr.io/fluentd-elasticsearch:v2.3.2
        ports:
        - name: metrics
          containerPort: 24231
          protocol: TCP
        image: sraghav1/fluentd-plugins:latest
        #image: quay.io/fluentd_elasticsearch/fluentd:v2.7.0
        env:
        - name: FLUENTD_ARGS
          value: -q
        resources:
          limits:
            memory: 1500Mi
          requests:
            cpu: 500m
            memory: 500Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: config-volume
          mountPath: /etc/fluent/config.d
        - name: pub-logs
          mountPath: /pub/logs
      - name: config-reloader
        image: sraghav1/fluentd-plugins:latest
        # imagePullPolicy: Always
        # NOTE: config.gracefulReload is supported in recent version of fluentd. But it won't work if prometheus_output_monitor plugin is used.
        # The latest version is throwing exception on config.reload in k8s metadata plugin. Stay with v2
        command: ["bash"]
        args: ["-c", "while true;\
                        do inotifywait -e modify,create,delete /etc/fluent/config.d/*;\
                        ret=$?;\
                        if [ $ret -eq 1 ]; then \
                           curl http://127.0.0.1:24444/api/config.reload;\
                        fi;\
                        sleep 1;\
                      done"]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/fluent/config.d
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: config-volume
        configMap:
          name: fluentd-es-config-v0.1.6-TEMPL_USERNAME
      - name: pub-logs
        hostPath:
          path: /pub/logs
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 20%
    type: RollingUpdate
