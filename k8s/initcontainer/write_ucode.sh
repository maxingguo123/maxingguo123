#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

# This script makes the assumption that both /lib and /sys from the host are
# mounted into the container at /lib and /sys
cp ucode/06* /lib/firmware/intel-ucode/
echo 1 > /sys/devices/system/cpu/microcode/reload || (echo "FAILED: Unable to load micro-code!!!" && true)
echo "Microcode Ver: " $(rdmsr 0x8b)
echo "Micro-Code Revisions: " $(cat ucode/ucode-ver.txt)
echo "Init-Container Revision: " $(cat init-cont-ver.txt)
exit 0
