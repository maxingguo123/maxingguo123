#!/bin/bash"

#IPC_HOST=login01.lab10b2.deacluster.intel.com
KINGKONG_IMG=kingkong_sqrt-v0.94.4
NS=$NS
JENKINS_NODE_LABEL=$JENKINS_NODE_LABEL

#THIS_HOST=`hostname|awk -F '.' '{print $1}'`
#MAX_ATTEMPTS=12

JOB_URL="http://atscale-jenkins.amr.corp.intel.com/job/Tests/job/Development/job/kingkong-test/"
REBOOT_URL="http://atscale-jenkins.amr.corp.intel.com/job/Tests/job/reboot-idle/"
FANSPEED_URL="http://atscale-jenkins.amr.corp.intel.com/job/Tests/job/Development/job/ipmi-fan-speed/"
REGISTER_URL="http://atscale-jenkins.amr.corp.intel.com/job/Tests/job/Development/job/kong-test-read-registers/"
ITERATIONS=1
TESTS=("kong" "ptu")


function read_registers()
{
	echo "Reading registers..."
    curl "${REGISTER_URL}/buildWithParameters?token=kongreadregisters&JENKINS_NODE_LABEL=${JENKINS_NODE_LABEL}&NS=${NS}&JENKINS_TEST_TAG=${KINGKONG_IMG}"

	sleep 120
	echo "Check fan speed job completion.."
	while true; do
		if  curl -s "${REGISTER_URL}/lastBuild/api/json?pretty=true&depth=1" | grep -q '"building" : true,'; then
			sleep 120
		else 
			exit
		fi
		sleep 120
	done
}


while true; do
  for  test in "${TESTS[@]}"; do
	
	read_registers

	#########
	# Set fan speeds to 37%
	#########
	echo "Set fan speeds.."
	curl "${FANSPEED_URL}/buildWithParameters?token=changefanspeed&SPEEDMODE=set&SPEEDVALUE='"25"'&NODELABEL=${JENKINS_NODE_LABEL}&NS=${NS}"
	sleep 120
	echo "Check fan speed job completion.."
	while true; do
		if curl -s "${FANSPEED_URL}/lastBuild/api/json?pretty=true&depth=1" | grep -q '"building": true,'; then
			sleep 30
		else
			exit
		fi
	done
	# Allow fan speed change to take effect
	sleep 300

	read_registers

	#########
	# Run content
	#########    
	echo "Scheduling ${test} job..."
        curl "${JOB_URL}/buildWithParameters?token=kickthekong&TEST=$test&JENKINS_NODE_LABEL=${JENKINS_NODE_LABEL}&NS=${NS}&JENKINS_TEST_TAG=${KINGKONG_IMG}"
	sleep 960
	echo "Check job completion..."
	while true; do
		if curl -s "${JOB_URL}/lastBuild/api/json?pretty=true&depth=1" | grep -q '"building": true,'; then
			sleep 30
		else 
			exit
		fi	
	done

	read_registers

	#########
	# Reset fan speeds to default value
	#########
	echo " Reset  fan speeds.."
	curl "${FANSPEED_URL}/buildWithParameters?token=changefanspeed&NODELABEL=${JENKINS_NODE_LABEL}&NS=${NS}"

	sleep 120

	echo "Check fan speed job completion.."
	while true; do
		if curl -s "${FANSPEED_URL}/lastBuild/api/json?pretty=true&depth=1" | grep -q '"building": true'; then
			sleep 30
		else
			exit
		fi
	done
	# Allow systems to cool down with fan speed change
	sleep 600

	read_registers

	#########
	# Reboot systems
	#########
	echo "Rebooting systems..."
    curl "${REBOOT_URL}/buildWithParameters?token=rebootsystems&JENKINS_NODE_LABEL=${JENKINS_NODE_LABEL}&NS=${NS}&CYCLES=1&IDLE=FALSE&REBOOT_TYPE=warm"

	sleep 300
	while true; do
		if curl -s "${REBOOT_URL}/lastBuild/api/json?pretty=true&depth=1" | grep -q '"building": true,'; then
			sleep 30
		else
			exit
		fi
	done

#	for node in `cat ~/ptu-tests`; do
#	  curl -k -s https://${node/s/b}/redfish/v1/Systems/system/Actions/ComputerSystem.Reset -H 'Content-Type: application/json' -H 'Authorization: Basic ZGVidWd1c2VyOjBwZW5CbWMx' -H 'Cache-Control: no-cache' -d '{"ResetType": "PowerCycle"}'
#	done
	sleep 600

  done
  echo "ITERATION ${ITERATIONS} COMPLETE!"
  ((ITERATIONS = ITERATIONS + 1))
done
