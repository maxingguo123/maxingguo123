# prt-int-cluster repository

Jenkins stuff to run the PRT internal cluster.

This repository includes pipelines, base-specific jobs, deploy files. 


## Base jobs

***Required***
```
env.JENKINS_TEST_TAG="container-registry"
env.JENKINS_TEST_LABEL="container-label-kibana"
env.JENKINS_NODE_LABEL="unifiednode" 
env.JENKINS_TEST_BINARY="\\/directory\\/directory2\\/binary"
env.JOB_RUNTIME=600
```
* `JENKINS_TEST_LABEL delimiter should be "-", this name will appear in kibana as:`
**kubernetes.container_name**
* `JENKINS_NODE_LABEL in the base is always "unifiednode"`
* `JOB_RUNTIME=(time in seconds)`



***Optional env.***
```
env.JENKINS_TEST_ARGS="--optional=1"
env.EMAIL="pdl.intel.com"
env.DEPLOYMENT_YAML_URL="https://gitlab-mirror-fm.devtools.intel.com/sandstone/prt-int-cluster/-/raw/master/ive/sandstone_run_specific.yaml"
env.SANDSTONE_DEPLOYMENT="${env.WORKSPACE}/sandstone_run_specific.yaml"
```

optional fields add functionality of:
* `add arguments to binary`
* `receive email every time the job runs in the cluster`
* `change the deploy file (only if necessary), yaml should be in this repository`
