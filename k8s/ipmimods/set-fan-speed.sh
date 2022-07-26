#!/bin/bash

set -o nounset

: {SPEED_MODE:="reset"}
: {SPEED_VALUE:=""}
OP=""

function usage() {
  echo ""
  echo "${0} -s <speed> | -r"
  echo ""
  exit 1
}

function set_speed() {
  if [ -z "$SPEED_VALUE" ] || [ "$SPEED_VALUE" == "SPEEDVALUE" ];then
    echo  "Speed not set"
    exit 1
  fi
  echo "Set fan speed  to $SPEED_VALUE"

  ipmitool raw 0x30 0xB4 0x3 2

  for i in {00..08}; do
    ipmitool raw 0x30 0x15 0x05 0x$i 0x01 0x$SPEED_VALUE
  done

  sleep  15
  #echo  "Reading fan speeds"
  #for i in  {1..8}; do
  #  ipmitool sensor get "Pwm $i"
  #  ipmitool sensor get "Fan $i"
  #done
}

function reset_speed()  {
  echo "Resetting fan speeds"
  ipmitool raw 0x30 0xB4 0x3 2
  for i in {00..08}; do
    ipmitool raw 0x30 0x15 0x05 0x$i 0x02
  done
}

case $SPEED_MODE in
  "set")    OP="set_speed";;
  "reset")  OP="reset_speed";;
  "*")      echo "Speed mode not recognized";;
esac

if [ ! -z ${OP} ]; then
  ${OP}
fi

# Notify we are done with setting speeds.
touch /tmp/donedone
sleep infinity
