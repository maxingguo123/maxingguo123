#!/bin/bash

###########################
# This script is to setup hosts with clearlinux in our local clusters.
###########################

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Some variables
export http_proxy=http://proxy-us.intel.com:911
export https_proxy=http://proxy-us.intel.com:912
export no_proxy=127.0.0.0/8,localhost,10.0.0.0/8,192.168.0.0/16,192.168.14.0/24,192.168.14.1,192.168.14.2,192.168.14.3,192.168.14.4,192.168.14.5,192.168.14.6,192.168.14.7,192.168.14.8,192.168.14.24,192.168.14.101,192.168.14.102,192.168.14.103,192.168.14.104,192.168.14.105,192.168.14.106,192.168.14.107,192.168.14.108,192.168.14.124,.intel.com
export CLR_VER=30700
export NTP=192.168.0.3
export FALLBACKNTP=10.18.116.209
export DEFROUTE=192.168.1.101

## If we need to set routing table to reach the intel network.
ip route add default via ${DEFROUTE} || true

## Setup NTP servers
mkdir -p /etc/systemd/system

cat > /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=${NTP}
FallbackNTP=${FALLBACKNTP}
EOF

systemctl enable systemd-timesyncd
systemctl restart systemd-timesyncd
timedatectl timesync-status

## Download mcelog binary
curl -OL http://illidan.sc.intel.com/images/mcelog
chmod +x mcelog
sudo mkdir -p /usr/local/bin/
sudo mv mcelog /usr/local/bin/

## MCE service file.
mkdir -p /etc/systemd/system
mkdir -p /usr/local/bin

cat > /etc/systemd/system/mcelog.service <<EOF
[Unit]
Description=Machine Check Exception Logging Daemon
After=syslog.target

[Service]
ExecStart=/usr/local/bin/mcelog --ignorenodev --daemon --foreground --json
StandardOutput=syslog
SuccessExitStatus=0 15

[Install]
WantedBy=multi-user.target
EOF

## Containerd config file.
mkdir -p /etc/containerd
cat > /etc/containerd/config.toml <<EOF
[plugins]
  [plugins.cri]
    max_container_log_line_size = 499900
    [plugins.cri.registry]
      [plugins.cri.registry.mirrors]
        [plugins.cri.registry.mirrors."prt-registry.sova.intel.com"]
          endpoint = ["https://prt-registry.sova.intel.com"]
        [plugins.cri.registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
EOF

## Install ansible and git for rsyslog & setup
pip install ansible
swupd bundle-add git

## Install rsyslog
ansible-pull -U https://sv-gitlab.igk.intel.com/mve-playbooks/rsyslog.git -C master -f

## Clone cloud-native-setup
git clone https://github.com/clearlinux/cloud-native-setup $HOME/cloud-native-setup

# Peg the clear version & set runner
sed -i "s/swupd update/swupd update -m ${CLR_VER}/" $HOME/cloud-native-setup/clr-k8s-examples/setup_system.sh
export RUNNER="containerd"

# Setup system for k8s
$HOME/cloud-native-setup/clr-k8s-examples/setup_system.sh

# Add default route as a service file.
mkdir -p /etc/systemd/system
mkdir -p /usr/local/bin

cat > /etc/systemd/system/clustergw.service <<EOF
[Unit]
Description=Service to add specific routes
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=30
User=root
ExecStart=-/usr/bin/ip route add default via ${DEFROUTE}

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now clustergw.service
