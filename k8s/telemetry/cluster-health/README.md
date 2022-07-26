# Cluster Health

Deployment that combines information from clusterscope and the Kubernetes API
to track the health of the cluster. Publishes results directly to elasticsearch
to an index pattern of `health*`.

## Create index mapping

If this is the first time cluster-health has been deployed on the cluster you
need to create the index mapping first.

```bash
CONFIG=opus ./setup-index.sh
```

## Deploy

```bash
CONFIG=opus ./setup.sh install
```

## OPUS

Copy the `atscale-es-cert` secret in the `monitoring` namespace to the
`kube-system` namespace.

```bash
kubectl get secret atscale-es-cert -n monitoring -o yaml > atscale-es-cert.yaml
sed -i 's/namespace: monitoring/namespace: kube-system/' atscale-es-cert.yaml
kubectl apply -f atscale-es-cert.yaml
```


