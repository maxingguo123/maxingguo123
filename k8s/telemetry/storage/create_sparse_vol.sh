#!/bin/bash

set -o errexit

name=$1
size=$2

if [[ $# -lt 2 ]]; then
	echo "$(basename ${0}) <NAME> <SIZE>"
        echo "SIZE may be (or may be an integer optionally followed by) one of following: KB 1000, K 1024, MB 1000*1000, M 1024*1024, and so on for G, T, P, E, Z, Y."
else
        if [[ -f "/vols/$name.img" ]]; then
		echo "volume already exists!"
	else
		mkdir -p /vols
		mkdir -p /disks
		truncate -s $size /vols/$name.img
		mkfs.ext4 /vols/$name.img
		mkdir /disks/$name
		mount -o loop /vols/$name.img /disks/$name/
		
		chmod 666 /vols/$name.img
		chmod 777 /disks/$name/

		if grep -q "$name.img" /etc/fstab; then
			echo "entry present in /etc/fstab already, skipping"
		else
			echo "/vols/$name.img /disks/$name ext4 loop,defaults 0 0" >> /etc/fstab
		fi
	fi
fi
