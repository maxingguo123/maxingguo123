#!/bin/bash

#ROOT_URL='ive-infra04.deacluster.intel.com:5000/api/node/metadata?name='
echo "Host: $HOST"
echo "URL: $ROOT_URL$HOST"
echo "Host IP: $HOST_IP"
echo "Pod IP: $POD_IP"
echo "Pod Name: $POD_NAME"
echo "Namespace: $POD_NAMESPACE"
echo "Location:  $LOCATION"
echo "Metadata: $CLUSTER_METADATA"

while true
do
  HOST=$(hostname)
  cs_location=$LOCATION
  # if host contains a .suffix, use all remaining name segmanets as location (e.g. r01s01.opmain3 location is opmain3, r02s02.opmain3.whatever location is opmain3.whatever)
  if [[ $(echo $HOST | awk -F"." '{print NF-1}') -gt 0 ]]; then
    cs_location=${HOST#*.}
  fi 
  rm node_details.json
  cat /dev/null > /tmp/memory.json
  lshw -class memory -json -quiet > /tmp/memory.json
  memConfig=$(lshw -businfo -class memory | grep -v 'empty\|controller' | grep 'DIMM' | awk '{printf "%s-%s%s-%s%s-",$2,$8,$9,$10,$11}')
  MVENDOR="$(cat /tmp/memory.json | jq -c '.[] | select(.slot | test("CPU|DIMM"))? | .vendor' | jq -rs 'join("|")')"
  MPARTNO="$(cat /tmp/memory.json | jq -c '.[] | select(.slot | test("CPU|DIMM"))? | .product' | jq -rs 'join("|")')"
  MSERIAL="$(cat /tmp/memory.json | jq -c '.[] | select(.slot | test("CPU|DIMM"))? | .serial' | jq -rs 'join("|")')"
  MFREQ="$(cat /tmp/memory.json | jq -c '.[] | select(.slot | test("CPU|DIMM"))? | if (.clock == null) then 0 else .clock/1000000 end' |  jq -rs 'join("|")')"
  MSIZE="$(cat /tmp/memory.json | jq -c '.[] | select(.slot | test("CPU|DIMM"))? | if (.size == null) then 0 else .size/1073741824 end' | jq -rs 'join("|")')"
  echo "Memory Config Summary:" $memConfig
  COLLDATE=$(date -u)
  curl --location --request GET "$ROOT_URL$HOST&location=$cs_location" | jq . | tee node_details.json
  QDF0=$(cat node_details.json | jq -r -c '."0".qdf')
  QDF1=$(cat node_details.json | jq -r -c '."1".qdf')
  CPLD=$(cat node_details.json | jq -r -c '.cpldVersion')
  BIOS=$(dmidecode -s bios-version)
  UCODE=$(cat /proc/cpuinfo | grep microcode | head -1 | awk '{print $3}')
  CPU=$(cat /proc/cpuinfo | grep "cpu family\|model\|stepping"| grep -v "name" | sort | uniq | xargs | paste -s)
  PPIN0=$(rdmsr -0 -a 0x4f | uniq | head -n 1)
  PPIN1=$(rdmsr -0 -a 0x4f | uniq | grep -v $PPIN0 | head -n 1)
  if [[ "$PPIN0" == "" ]]; then
      PPIN0="unknown"
  else
      PPIN0="0x$PPIN0"
  fi
  if [[ "$PPIN1" == "" ]]; then
      PPIN1="unknown"
  else
      PPIN1="0x$PPIN1"
  fi
  cat node_details.json | jq -c \
    --arg hos "$HOST" \
    --arg mcfg "$memConfig" \
    --arg MVENDOR "$MVENDOR" \
    --arg MPARTNO "$MPARTNO" \
    --arg MSERIAL "$MSERIAL" \
    --arg MFREQ "$MFREQ" \
    --arg MSIZE "$MSIZE" \
    --arg colldate "$COLLDATE" \
    --arg p0 "$PPIN0" \
    --arg p1 "$PPIN1" \
    --arg q0 "$QDF0" \
    --arg q1 "$QDF1" \
    --arg cpldv "$CPLD" \
    --arg b "$BIOS" \
    --arg ucode "$UCODE" \
    --arg cpu "$CPU" '. 
    | {name, biosVersion , bmcVersion ,cpuId ,meVersion ,pool ,platform ,location ,stepping} 
    | . += {"hostname": $hos, "MEMCFG": $mcfg, "ppin0": $p0, "ppin1": $p1, "qdf0": $q0, "qdf1": $q1, "hBios": $b, "hMicrocode": $ucode, "hCpu": $cpu, "cpldVersion": $cpldv, "date": $colldate} 
    | . += {"MEMINFO": {"VENDOR": $MVENDOR, "PART_NO": $MPARTNO, "SERIAL": $MSERIAL, "FREQUENCY": $MFREQ, "SIZE": $MSIZE }}' \
    | tee "$CLUSTER_METADATA" \
    | jq -c '. += {"type": "clusterscope-metadata"}' \
    | tee /hostroot/dev/console
  sleep 300
done
