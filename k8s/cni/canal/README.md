# Canal CNI

## Configuration

The network and subnetlen values should be changed to match our pod network and subnet. For a new version of Canal,
download the yaml (e.g. https://projectcalico.docs.tigera.io/v3.22/manifests/canal.yaml) and then modiy as below:

```
  # Flannel network configuration. Mounted into the flannel container.
  net-conf.json: |
    {
      "Network": "100.64.0.0/12",
      "SubnetLen": 24,
```

## Installation

Example installation of Canal (v3.22):

```
kubectl apply -f v3.22/canal.yaml
```
