#!/bin/bash
while :
do
	python3 XmlCliCmd.py readknobs
	sleep $XC_INTERVAL
done
