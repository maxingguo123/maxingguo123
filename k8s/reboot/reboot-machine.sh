#!/bin/bash

#By Default we will also do a full cold reboot
: ${REBOOT_TYPE:="cold"}
: ${REBOOT_COUNT_FILE="/hostroot/cluster-reboot-count"}
: ${IPADDRESS_FILE="/hostroot/bmc-address"}

##############
# FUNCTIONS
##############
function get_address() {
    if [ ! -f ${IPADDRESS_FILE} ]; then
        ipmitool lan print 3 | grep -v "IP Address Source" | grep "IP Address" \
        | cut -d ":" -f2 | tr -d " \t\n\r" > ${IPADDRESS_FILE}
    fi
}

function validate_integrity(){
    if [[ $(cat ${IPADDRESS_FILE}) =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; 
        then
          echo "ok - BMC IP Integrity"
          echo "ok - Sending redfish request..."
        else
          echo "not ok - BMC IP Integrity"
          rm -rf ${IPADDRESS_FILE}
          exit 1
    fi
}


if ${REBOOT_NODE} ; then
  if [ -f /hostroot/cluster-reboot ]; then
    echo "REBOOT COUNT: $(cat ${REBOOT_COUNT_FILE})"
    echo "Reboot complete. Sleeping.."
    touch /tmp/donedone
    sleep infinity
  else
    # Allow fluentd to be able to push the log before rebooting
    echo "REBOOT TYPE: ${REBOOT_TYPE}"
    sleep 10
    touch /hostroot/cluster-reboot
    if [ ! -f ${REBOOT_COUNT_FILE} ]; then
      echo "1" > ${REBOOT_COUNT_FILE}
    else
      echo "$(($(cat ${REBOOT_COUNT_FILE})+1))" > ${REBOOT_COUNT_FILE}
    fi
    if [[ "${REBOOT_TYPE}"  == *"rf_"* ]]; then
      get_address
      validate_integrity
    fi
    sync
    while true; do
      case "${REBOOT_TYPE}" in
        "os_warm") reboot;;
        "cold") ipmitool power cycle;;
        "warm") ipmitool power reset;;
        "rf_cold") curl --fail --silent --show-error -k --location --request \
        POST "https://$(cat ${IPADDRESS_FILE})/redfish/v1/Systems/system/Actions/ComputerSystem.Reset" --header 'Content-Type: application/json' --data '{"ResetType": "PowerCycle"}' -u debuguser:0penBmc1 > /dev/null;;
        "rf_warm") curl --fail --silent --show-error -k --location --request \
        POST "https://$(cat ${IPADDRESS_FILE})/redfish/v1/Systems/system/Actions/ComputerSystem.Reset" --header 'Content-Type: application/json' --data '{"ResetType": "ForceRestart"}' -u debuguser:0penBmc1 > /dev/null;;
        ?) echo "Unable to determine the type of reboot" && exit 1;;
      esac
    sleep 10
  done
  fi
else
  echo "No reboot request. Sleeping.."
  touch /tmp/donedone
  sleep infinity
fi
