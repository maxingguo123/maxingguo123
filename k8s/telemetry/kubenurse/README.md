# Simple tool to monitor network connectivity across the cluster

Based on github.com/postfinance/kubenurse

# How to deploy

kubectl apply -n kube-system -f ./kubenurse

# Modifications

This results in an explosion of cardinality.
We limit this by monitoring just the telemetry VMs which are critical.

# Dealing with high cardinality

Visulazation of data with this degree of cardinality is hard.
So just track the rate of change. Also our cluster has issues
with resolution of external facing services. Hence ignore `me_ingress` errors for now.

`increase(kubenurse_errors_total{type!="me_ingress"}[1m]) > 0`

# TODO

Currently we need to run in kube-system due to `RBAC`.
