#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

: ${INIT_MSR_SET:=}

echo "Starting Init sequence.."

if [ -n "${INIT_MSR_SET}" ]; then
  $(pwd)/set_msr.sh ${INIT_MSR_SET}
fi

echo "All done!"
exit 0
