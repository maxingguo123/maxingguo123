# Kowl UI for Kafka

Install the [Kowl UI for Kafka](https://github.com/cloudhut/charts/tree/master/kowl)

## Deploy

To deploy, specify the name of your values file by setting the CONFIG environment variable. The below example would look for a `dev.yaml` values file in the `values` directory.

```
CONFIG=dev ./setup.sh install
```

## Remove

```
CONFIG=dev ./setup.sh teardown
```
