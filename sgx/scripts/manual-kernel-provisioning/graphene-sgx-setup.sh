#!/bin/bash

HTTPSERVER="http://r31s01.deacluster.intel.com:8000"
TARBALL="graphene-sgx-kernel.tar"
LOADERENTRY="/boot/loader/entries/jbkonno-5.10-rc3.conf"
RULESFILE="/etc/udev/rules.d/10-sgx.rules"

set -x

mount /dev/nvme0n1p1 /boot || exit 1
mkdir -p /etc/udev/rules.d || exit 1

curl --retry 10 -O $HTTPSERVER/$TARBALL || exit 1
tar xf graphene-sgx-kernel.tar || exit 1
cp boot/vmlinuz* /boot || exit 1
# Because Clear... K8S needs to find the kernel config in magic location... here?
cp boot/config-* /boot || exit 1
cp boot/System.map* /boot || exit 1
# ... and/or here?
cp boot/config-* /usr/lib/kernel || exit 1
cp boot/System.map* /usr/lib/kernel || exit 1
cp -av lib/modules/5.10.0-rc3-jbk+ /lib/modules/ || exit 1

# Boot loader entry and default
echo "title      Clear Linux OS" > $LOADERENTRY
echo "version    5.10.0-rc3-jbk+" >> $LOADERENTRY
echo "options    root=/dev/nvme0n1p3 modprobe.blacklist=ccipciedrv,aalbus,aalrms,aalrmc console=tty0 console=ttyS0,115200n8 init=/usr/lib/systemd/systemd-bootchart initcall_debug tsc=reliable noreplace-smp kvm-intel.nested=1 rootfstype=ext4,btrfs,xfs cryptomgr.notests rcupdate.rcu_expedited=1 i915.fastboot=1 rcu_nocbs=0-64 rw module.sig_unenforce cpu0_hotplug log_buf_len=15M" >> $LOADERENTRY
echo "linux      /vmlinuz-5.10.0-rc3-jbk+" >> $LOADERENTRY

mv /boot/loader/loader.conf /boot/loader/loader.conf.orig
echo "default jbkonno-5.10-rc3.conf" > /boot/loader/loader.conf
echo "timeout 10" >> /boot/loader/loader.conf

# UDEV entries for symlinking SGX devfs nodes
echo "SUBSYSTEM==\"misc\",KERNEL==\"sgx_enclave\",MODE=\"0666\",SYMLINK+=\"sgx/enclave\"" > $RULESFILE
echo "SUBSYSTEM==\"misc\",KERNEL==\"sgx_provision\",GROUP=\"wheel\",MODE=\"0660\",SYMLINK+=\"sgx/provision\"" >> $RULESFILE

bootctl status
