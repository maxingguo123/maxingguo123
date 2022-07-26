set -x

set_labels() {
	fluentd=$1
	file=$2
	runid=$3
	test=$4

	sed -e "s/RUNID_NOTSET/$runid/g" -e "s/TEST_NOTSET/$test/g" $file | kubectl apply -f -
	#update pod annotation to trigger immediate configmap update
        kubectl annotate pods --selector=k8s-app=$fluentd --overwrite run=$runid-$test
	sleep 10 # wait few seconds for fluentd to reload
}

run() {
	#iterate through list of workloads and deploy sim
	runtime=120
	runid=run-`cat /dev/urandom | tr -dc a-z0-9 | fold -w 6 | head -1`
	fluentd_conf=~/src/ci/GCP/cluster-infra/telemetry/fluentd/es/out/fluentd-es-configmap.yaml
	fluentd_prom_conf=~/src/ci/GCP/cluster-infra/telemetry/fluentd/prom/fluentd-prom-configmap.yaml
	
	for w in imunch-stable imunch-replay dragon-depth dragon-breadth sandstone
	do
		# Create YAML and expand template
		cp logsim.yaml.tpl out/logsim.yaml
		sed -i "s/WORKLOAD/$w/g" out/logsim.yaml
		sed -i "s/RUNTIME/$runtime/g" out/logsim.yaml
		sed -i "s/RUNID/$runid/g" out/logsim.yaml
	
	
		#Set runid and test labels
		set_labels fluentd-es $fluentd_conf $runid $w
		set_labels fluentd-prom $fluentd_prom_conf $runid $w
	
		# Run the test
		kubectl apply -f out/logsim.yaml
		sleep $((runtime + 10)) #extra time for pods to complete
		kubectl delete -f out/logsim.yaml
		#Wait till pods are actually deleted
		until [[ "`kubectl get pods --selector=name=$w`" == "" ]]; do sleep 1; done

		#remove test label. keep run label
		sleep 30 #Give prometheus a chance to scrape metrics from fluentd before changing labels
		set_labels fluentd-es $fluentd_conf $runid TEST_NOTSET
		set_labels fluentd-prom $fluentd_prom_conf $runid TEST_NOTSET
	done
	
	#Remove all labels - revert to original file
	set_labels fluentd-es $fluentd_conf RUN_NOTSET TEST_NOTSET
	set_labels fluentd-prom $fluentd_prom_conf RUN_NOTSET TEST_NOTSET
}

run
