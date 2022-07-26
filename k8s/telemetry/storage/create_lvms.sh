#!/bin/bash

set -o errexit

device=$1
name=$2
size=$3

if [[ $# -lt 2 ]]; then
	echo "$(basename ${0}) <DEVICE> <NAME> <SIZE>"
        echo "SIZE may be (or may be an integer optionally followed by) one of following: KB 1000, K 1024, MB 1000*1000, M 1024*1024, and so on for G, T, P, E, Z, Y."
else
        if [[ ! -d "/dev/telemetry_data" ]]; then 
		pvcreate $device
		vgcreate telemetry_data $device
	else
		echo "VG already exists!"
	fi

        if [[ ! -b "/dev/telemetry_data/$name" ]]; then 
		lvcreate -n $name -L $size telemetry_data
		
		mkfs.ext4 /dev/telemetry_data/$name
		mkdir -p /disks/$name
		mount /dev/telemetry_data/$name /disks/$name/
		chmod 777 /disks/$name/

		if grep -q "/dev/telemetry_data/$name" /etc/fstab; then
			echo "entry present in /etc/fstab already, skipping"
		else
			echo "/dev/telemetry_data/$name /disks/$name ext4 defaults 0 0" >> /etc/fstab
		fi
	else
		echo "LV already exists!"
	fi
fi
