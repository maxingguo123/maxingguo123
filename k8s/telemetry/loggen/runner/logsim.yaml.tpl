apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: WORKLOAD
  namespace: default
  labels:
    k8s-app: WORKLOAD
spec:
  selector:
    matchLabels:
      name: WORKLOAD
  template:
    metadata:
      labels:
        name: WORKLOAD
        runid: RUNID
    spec:
      hostNetwork: true
      nodeSelector:
        role: loggen
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: workload
        image: centos/systemd
        imagePullPolicy: IfNotPresent
        command: ["/usr/bin/bash"]
        args: ["-c", "echo 'Starting Init sequence...';\
                      sleep RUNTIME;\
                      r=$(( RANDOM % 28));\
                      echo $r;\
                      if [[ $r -eq 1 ]]; \
                      then echo 'not ok 12 cache_stress_memcpy'; \
                        sleep 0.1; \
                        echo 'TEST FAILED'; \
                     elif [[ $r -eq 2 ]]; \
                     then echo 'oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=b0eb25f1d4ffa5dd44f41ae601c56f36b9ee6feccca5427e50255483eb857bb3,mems_allowed=0-1,oom_memcg=/kubepods/burstable/podf71f348b-6ac3-4559-ab9d-9c0726e6c6b6,task_memcg=/kubepods/burstable/podf71f348b-6ac3-4559-ab9d-9c0726e6c6b6/b0eb25f1d4ffa5dd44f41ae601c56f36b9ee6feccca5427e50255483eb857bb3,task=node-problem-de,pid=13973,uid=0'; \
                       sleep 0.1; \
                       echo 'TEST PASSED'; \
                     elif [[ $r -eq 3 ]]; \
                     then echo 'log_monitor.go:64] Finish parsing log monitor config file: {WatcherConfig:{Plugin:kmsg PluginConfig:map[] LogPath:/dev/kmsg Lookback:5m Delay:} BufferSize:100 Source:kernel-monitor DefaultConditions:[] Rules:[{Type:permanent Condition: Reason:Hardware Error Pattern:mce:.*} {Type:permanent Condition: Reason:Hardware Error Pattern:traps.*} {Type:permanent Condition: Reason:Hardware Error Pattern:runc:*} {Type:permanent Condition: Reason:Hardware Error Pattern:Code:*} {Type:temporary Condition: Reason:Hardware Error Pattern:oom-kill:.*'; \
                       sleep 0.1; \
                       echo 'TEST PASSED'; \
                     elif [[ $r -eq 4 ]]; \
                     then echo '[    3.654071] mce: [Hardware Error]: PROCESSOR 0:50654 TIME 1576079913 SOCKET 1 APIC 40 microcode 200005e'; \
                       sleep 0.1; \
                       echo 'TEST PASSED'; \
                     elif [[ $r -eq 5 ]]; \
                     then echo 'Dec 12 22:25:21 ip-192-168-0-92 kernel: mce: CPU0: Package temperature above threshold, cpu clock throttled (total events = 1000)'; \
                       sleep 0.1; \
                       echo 'TEST PASSED'; \
                     elif [[ $r -eq 6 ]]; \
                     then echo '# WARNING: test zstd time over 25% more than the expected time (2495.42 ms > 625 ms). Please check the test'; \
                       sleep 0.1; \
                       echo 'TEST PASSED'; \
                     elif [[ $r -eq 7 ]]; \
                     then echo '# WARNING: test ipsec_aes128_docsis_hmac_sha1_avx took less than 80% of the expected time (196.232 ms < 240 ms). Please check the test'; \
                       sleep 0.1; \
                       echo 'TEST PASSED'; \
                      else echo 'TEST PASSED'; \
                     fi;sleep infinity"]
