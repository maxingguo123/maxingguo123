#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

: ${REGISTER:=}
: ${VALUE:=}
: ${REREAD:=}
: ${CPU:=}
MSR_ARGS=""

# Script to write MSR onto the host. Takes an input which should be in the
# format "REGISTER:VALUE". The script will split with ':' and set the
# register's value.
# Usage: set_msr.sh REGISTER:VALUE

if [ -z ${1-} ]; then
  echo "No idea what to set!! Bye now!"
  exit 0
fi

if [ -z ${2-} ]; then
  MSR_ARGS+="--all"
else
  MSR_ARGS+="-c ${CPU}"
fi

REGISTER=$(echo $1 | awk -F ':' '{print $1}')
VALUE=$(echo $1|  awk -F ':' '{print $2}')

# There might be systems where the register cannot be written into (CPU locked,
# Wrong micro-code, etc). Ignore the error return you get from MSR and continue

# Always write 0 prior to writing to the actual value. (The Experts said so, I have no idea why!)
wrmsr ${MSR_ARGS} ${REGISTER} 0x0 || true

# Now write the right value.
wrmsr ${MSR_ARGS} ${REGISTER} ${VALUE} || true

# TODO: Check why we are not able to read the value after setting it.
# Time to check it.
#REREAD=$(rdmsr ${MSR_ARGS} --hexadecimal ${REGISTER})
#for val in ${REREAD}; do
#  if [[ $(printf "%x" ${val}) -ne $(printf "%x" ${VALUE}) ]]; then
#    echo "Register was not set!"
#    exit 1
#  fi
#done
exit 0
