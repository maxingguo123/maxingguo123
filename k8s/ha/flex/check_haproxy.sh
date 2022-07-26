#!/bin/sh

VIP=10.45.128.9
PORT=6666

if ! nc -z -w 3 localhost ${PORT}
  then
  echo "Port ${PORT} is not available." 1>&2
  exit 1
fi

#if ip addr | grep -q ${VIP}
#  then
#  if ! curl --silent --max-time 2 --insecure https://${VIP}:${PORT}/ -o /dev/null
#    then
#    echo "https://${VIP}:${PORT}/ is not available." 1>&2
#    exit 1
#  fi
#fi
