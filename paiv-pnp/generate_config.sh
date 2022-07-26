#!/bin/bash


# Constant varible
OVERIDE=NO

function printUsage() {
    echo -e "This program will generate a config file CONFIG_NAME.PLATFORM (ex. mlc_idle_latency.spr) with cluster disired format"
    echo -e "Usage:"
    echo -e "$0 -i DOCKER_TAG -w CONFIG_NAME -p PLATFORM -b BINARY [ -a ARGS ] -c CYCLES -t BASETIME [-o OVERIDE]"
    echo -e "  DOCKER_TAG: TAG part in imaage prt-registry.sova.intel.com/sandstone:TAG"
    echo -e "  CONFIG_NAME: the name for the config, generaly workload name, ex. mlc_idle_latency"
    echo -e "  PLATFORM: platform for the config, can be [icx | spr]"
    echo -e "  BINARY: test binary, ex. /home/MLC_idle_latency/src/run_all.sh"
    echo -e "  ARGS: test args for test binary, optional arguments"
    echo -e "  CYCLES: desired cycles for the workload test"
    echo -e "  BASETIME: job run time in seconds for 1 iteration of workload"
    echo -e "  OVERIDE: if YES, will overide exisiting file with same name, default is NO"
}

# deal with params
while getopts :i:w:p:b:a:c:t:o:h OPT
do
    case ${OPT} in
        i)
            DOCKER_TAG=${OPTARG};;
        w)
            CONFIG_NAME=${OPTARG};;
        p)
            PLATFORM=${OPTARG};;
        b)
            BINARY=${OPTARG};;
        a)
            ARGS=${OPTARG};;
        c)
            CYCLES=${OPTARG};;
        t)
            BASETIME=${OPTARG};;
        o)
            OVERIDE=${OPTARG};;
        h)
            printUsage
            exit
            ;;
    esac
done

# check parasm
if ! [[ "${PLATFORM}" =~ ^(spr|icx)$ ]]; then
    echo "Invalid Platform, exit..."
    exit
fi

echo ${OVERIDE}

if ! [[ "${OVERIDE}" =~ ^(YES|NO)$ ]]; then
    echo "Invalid OVERIDE param, exit..."
    exit
fi
    

CONFIG_NAME_TRANSFORMED=$(echo ${CONFIG_NAME} | tr -s '_' '-')
CONTAINER_NAME="paiv-pnp-${PLATFORM}-main-${CONFIG_NAME_TRANSFORMED}"
BINARY_ESCAPED=$(echo ${BINARY} | sed 's/\//\\\\\//g')
ARGS_ESCAPED=$(echo ${ARGS} | sed 's/\//\\\\\//g')
YAML="https://raw.githubusercontent.com/intel-innersource/applications.infrastructure.data-center.jenkins.prt-int-cluster/main/paiv-pnp/paiv_pnp_${PLATFORM}_general.yaml"


file_name="${CONFIG_NAME}.${PLATFORM}"
if [ -f ${file_name} ] && [ " ${OVERIDE} " = " NO " ]; then
    echo "File exists, no overide, exit..."
    exit
elif [ -f ${file_name} ] && [ " ${OVERIDE} " = " YES " ]; then
    echo "File exists, overide file ${file_name}"
    : > ${file_name}
else
    echo "Creating config file ${file_name}"
    : > ${file_name}
fi

# redirect STDOUT to file
exec 3>&1
exec 1>${file_name}

echo "import java.lang.Math"
echo
echo "env.JENKINS_TEST_TAG=\"${DOCKER_TAG}\""
echo "env.JENKINS_TEST_LABEL=\"${CONTAINER_NAME}\""
echo "env.JENKINS_NODE_LABEL=\"unifiednode\""
echo "env.JENKINS_TEST_BINARY=\"${BINARY_ESCAPED}\""
if [ -n "${ARGS}" ]; then
    echo "env.JENKINS_TEST_ARGS=\"${ARGS_ESCAPED}\""
fi
echo "// Use env.EXTRA_ARGS_ARG to control the test cycles"
echo "env.EXTRA_ARGS_ARG=\"${CYCLES}\""
echo "// Runtime should be: (1 + buffer) * cycles * basetime round to an integer"
echo "// Here basetiem is ${BASETIME}, buffer is 30%"
echo "env.JOB_RUNTIME=Math.round(1.3f * env.EXTRA_ARGS_ARG.toInteger() * ${BASETIME})"
echo 
echo "env.DEPLOYMENT_YAML_URL=\"${YAML}\""
echo "env.SANDSTONE_DEPLOYMENT=\"\${env.WORKSPACE}/paiv_pnp_${PLATFORM}_general.yaml\""

# Resume STDOUT
exec 1>&3

echo "Done"
