FBIT_PATH=/home/sraghav1/src/cluster-infra/k8s/telemetry/fluent-bit
docker run --rm --name fluentbit -v $FBIT_PATH/conf:/fluent-bit/etc:rw -v /var/log:/var/log:rw fluent/fluent-bit /fluent-bit/bin/fluent-bit -c /fluent-bit/etc/fluentbit.conf -v
