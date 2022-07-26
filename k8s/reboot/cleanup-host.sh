#!/bin/bash

: ${CLEAN_COUNTER:="false"}
: ${REBOOT_COUNT_FILE:="/hostroot/cluster-reboot-count"}
: ${IPADDRESS_FILE="/hostroot/bmc-address"}

rm /hostroot/cluster-reboot
if ${CLEAN_COUNTER}; then
  rm ${REBOOT_COUNT_FILE}
  rm ${IPADDRESS_FILE}
fi
touch /tmp/donedone
echo "Cleanup Complete!"
sleep infinity
