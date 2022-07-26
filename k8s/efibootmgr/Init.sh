#!/bin/bash


# gracefully handle the TERM signal sent when deleting the daemonset
trap 'exit' TERM



# this is a workaround to prevent the container from exiting
# and k8s restarting the daemonset pod
while true; do sleep 10; done
