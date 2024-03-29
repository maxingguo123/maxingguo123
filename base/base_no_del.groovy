import javax.mail.*
import javax.mail.internet.*
def private runType

def init(type=null) {
    runType = type
    def dep_yaml = env.SANDSTONE_DEPLOYMENT ?: "${env.WORKSPACE}/sandstone_run_specific.yaml"

    withCredentials([string(credentialsId: 'onesource', variable: 'SECRET')]) { //set SECRET with the credential content
        if (env.DEPLOYMENT_YAML_URL) {
            if(env.DEPLOYMENT_YAML_URL.contains("github")) {
                index = "https://raw.githubusercontent.com".length()
                end = env.DEPLOYMENT_YAML_URL.substring(index)
                sh 'https_proxy=proxy-dmz.intel.com:912 curl -O https://$SECRET@raw.githubusercontent.com'+end
            } else if(env.DEPLOYMENT_YAML_URL.contains("gitlab")) {
                sh "curl -O ${env.DEPLOYMENT_YAML_URL}"
            } else {
                echo "DEPLOYMENT_YAML_URL=${env.DEPLOYMENT_YAML_URL} does not match github or gitlab URL pattern"
            }
        } else {
            sh 'https_proxy=proxy-dmz.intel.com:911 curl -O https://$SECRET@raw.githubusercontent.com/intel-innersource/applications.infrastructure.data-center.test-cluster.cluster-infra/main/k8s/sandstone_run_specific.yaml'
        }
    }

    switch(runType) {
        case "virt":
            sh "sed -i '/^.*hostNetwork.*/i\\      runtimeClassName: kata-qemu' \'${dep_yaml}\'"
            break;
        case "tdx":
            sh "sed -i '/^.*hostNetwork.*/i\\      runtimeClassName: kata-qemu-tdx' \'${dep_yaml}\'"
            break;
        default:
            break;
    }
    withCredentials([string(credentialsId: 'onesource', variable: 'SECRET')]) { //set SECRET with the credential content
        sh 'https_proxy=proxy-dmz.intel.com:911 curl -O https://$SECRET@raw.githubusercontent.com/intel-innersource/applications.infrastructure.data-center.test-cluster.cluster-infra/main/k8s/jenkins-cluster-cd-specific.sh'
    }
    sh 'chmod +x jenkins-cluster-cd-specific.sh'
}

def run(time) {
    if (env.PRE_YAML) {
        sh "bash -x \"${env.WORKSPACE}/base/pre-yaml.sh\" apply"
    }
    def dep_yaml = env.SANDSTONE_DEPLOYMENT ?: "${env.WORKSPACE}/sandstone_run_specific.yaml"
    print dep_yaml
    withEnv(["SANDSTONE_DEPLOYMENT=${dep_yaml}"]) {
        echo sh(script: 'env|sort', returnStdout: true)
        sh "bash -x \"/var/local/common/cluster/jenkins-cluster-cd-specific-no-deletion.sh\" ${time}"
    }
}


def email(){
    if (env.EMAIL) {
        CLUSTER = "Undefined"
        if(env.KUBECTL_ARGS.contains("opus")){
            CLUSTER="OPUS"
        } else if (env.KUBECTL_ARGS.contains("icx-1")){
            CLUSTER="ICX-1"
        } else if (env.KUBECTL_ARGS.endsWith(".config")){
            CLUSTER="Purley"
        }
        sh "python \"${env.WORKSPACE}/base/email_jenkins.py\" ${env.JENKINS_TEST_LABEL} ${env.NS} ${env.EMAIL} ${CLUSTER}"
    }
}


def reset() {
    // Function to null env variables that should not be propogated to the next
    // run
    email()
    env.ITERATIONS = (1 as int)
    env.NS="default"
    env.EMAIL=""
    env.SANDSTONE_DEPLOYMENT="${env.WORKSPACE}/sandstone_run_specific.yaml"
}
return this
