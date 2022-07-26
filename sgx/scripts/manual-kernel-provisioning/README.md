# SGX Kernel Build and Deploy

- [Distro Specific Builds](#distro-builds)
- [Generic Builds](#generic-builds)
- [Test kernels](#test-kernels)
- [Sanity Checks](#sanity-checks)

All instructions are catered to a SGX audience and are designed to quickly
build and test sgx fixes in a small set of systems. For huge cluster
deployments, there are other processes to build those kernels. Please contact
the cluster team on that work.

# Distro Specific Builds
The steps below will help you build a kernel for two major distributions that
exist in our internal clusters. Ubuntu and Centos. The script are generic
enough that you can expand them to work on other distributions if required.

## Get the sources
Make sure you have the right kernel and all the patches you wish to compile and
test in the tree. SGX first revision has landed in 5.11-rc1 kernel and is good
to use a tree with atleast that version for your tests.

This tutorial will show you instructions of using the upstream kernel tree, but
there are instances where the intel-next kernel will be needed.

  * Upstream kernel  
    `git clone git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git --depth=50 -b tags/v5.11-rc2`
  * Intel-next kernel  
    `git clone ssh://git@gitlab.devtools.intel.com:29418/intel-next/intel-next-kernel.git`  
    PS: You will need to apply for an AGS to get access to this gitlab.  
    **DevTools - GitLab - Intel Next - Reporter** in https://ags.intel.com/identityiq/home.jsf

For baseline configuration, best to use the Host OS's kernel config (.config/Kconfig).
For both centos and ubuntu, you will be able to find the config in `/boot`.
Copy the config file to the new cloned kernel tree.

  * `cp /boot/config-$(uname -r) .config`

## Create the container
With the kernel sources, the script, `build-kernel-container.sh` will help you
create a container of the respective distro will all the packages needed to
generate either the rpm or deb file.

  * `./build-kernel-container.sh -d <distro> -k <path to the kernel sources>`

## Build the kernel
Get into the container and build the images.

  * `docker exec -it (ubuntu|centos)-kernel-builder bash`
  * `cd <path to the kernel source>`
  * `make olddefconfig` [You will now have a `.config` and a `.config.old`. You can diff them to see what got changed by the tooling and the distros]
  * If you wish to modify the kernel config to add/remove or change any selection, run
    `make menuconfig` and search for your configs and made the necessary changes.
    In our case, search for `CONFIG_X86_SGX` and set to `y`.
  * Save and exit.

You can now build the kernel
  * `make -j (binrpm|bindeb)-pkg`

The rpm resulting files are located at `~/rpmbuild/RPMS/x86_64` and the deb
files will be placed at the top directory of the kernel tree, literally `../`
from the kernel source

## Transfer to nodes
  * You will need a control node, ideally on the same network as your target nodes
for speed reasons.

  * Copy the deb or rpm package file to the folder on the control node.

  * Launch a dumb, stupid, insecure python3 HTTP server to host the content:
    * `./start-server.sh`

Your control node is now ready for provisioning.

## Deploy the kernel
Using whatever method you like (tmux, ansible, etc) to communicate with your
list of target nodes...

  * On your control node, identify the node's FQDN: 
    * `export URL=http://$(hostname -A | awk '{ print $1 }')`

  * Export the value of `URL` to each of your nodes, however you like

  * Issue the following command to each of your target nodes (script assumes you
      * For centos
        * `rpm -Uvh -f $URL/<kernel-file>.rpm`
        * `grubby --default-kernel` [Verify the newly installed kernel is the default one]
        * If it is not,
        * `grubby --info=ALL`
        * Find the path of the kernel that was just installed.
        * `grubby --set-default=<path to kernel>`

      * For ubuntu
      * `dpkg -i $URL/<kernel-file>.rpm`

  * Reboot the systems.
    * `reboot`

# Generic Builds
This is a fairly generic process. There are distro-specific ways of
building/packaging a kernel, but this is the "generic" way to to do it, and
should work for any distribution that uses systemd and systemd-boot/gummiboot.

(If your distro uses grub/another-bootloader, does not use systemd, or is not
EFI based, you will have to adapt the entire process.)

## Build the kernel

Clone a kernel containing the driver content you require (but the provisioned
Host OS's kernel does not provide). For SGX, that is Jarkko's kernel:
  * `git clone https://git.kernel.org/pub/scm/linux/kernel/git/jarkko/linux-sgx.git`
  * `git -C linux-sgx numa`

For baseline configuration, best to use the Host OS's kernel config (kconfig).
Assuming the Host OS is Clear Linux, this is located in
`/usr/lib/kernel/config-*`. Copy that kconfig into your newly-cloned kernel
source tree, and then:
  * `mv config-5.9.whatever .config`

Now, refresh it:
  * `make olddefconfig`

You now have a `.config` and a `.config.old`. If you diff them, you should see
subtle changes. If the delta is large, there may be notes about certain drivers
being unable to be built as a module, or some such. That output is important,
so follow up and make sure `.config` is as close to `.config.old` as it can
possibly be.

Now, modify your config to include new options that the Host OS's kconfig
doesn't have. For our purposes, that's SGX:
  * `make menuconfig`
  * Search for `CONFIG_X86_SGX` and set to `y`
  * Save and exit.

You can now make your kernel:
  * `make -j $(nproc) tar-pkg`

For size reasons, you'll likely want to prune away for `vmlinux`, which is only
needed if you intend to do remote gdb debugging on the target kernel.
  * `tar tf *.tar | grep -i vmlinux`

Then trim away `vmlinux`-- can save many tens of megabytes of network traffic
to target nodes:
  * `tar -vf <your-kernel-archive.tar> --delete <path/to/vmlinux-*>`

You now have a kernel tarball containing the bzImage and modules. Now for
transferring it, and the provisioning script, to the nodes.

## Transfer to nodes

You will need a control node, ideally on the same network as your target nodes
for speed reasons.

Copy the tarball you made before to this folder, and symlink it:
  * `ln -s <your-kernel-archive.tar> graphene-sgx-kernel.tar`

Launch a dumb, stupid, insecure python3 HTTP server to host the content:
  * `./start-server.sh`

Your control node is now ready for provisioning.

## Provision the kernel

Using whatever method you like (tmux, ansible, etc) to communicate with your
list of target nodes...

On your control node, identify the node's FQDN:
  * `export URL=http://$(hostname -A | awk '{ print $1 }')`

Export the value of `URL` to each of your nodes, however you like

Issue the following command to each of your target nodes (script assumes you
are `root`):
  * `curl -s --retry 10 -O ${URL}/graphene-sgx-setup.sh`

Each node should now have the provisioning script. Now, have each target node
run it:
  * `bash ./graphene-sgx-setup.sh`

One each target node returns from the script, it is provisioned.

You can now issue the following to each node to reboot:
  * `reboot`

# Test Kernels
To test the kernel, it would be good to spin up a VM and see if the kernel
boots without any hiccups. This is just to test if the kernel can boot on a
system properly without any major issues.

* Download the KVM image of the distro you would like to validate.
  * Ubuntu Focal: https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
  * Centos 8 Stream: https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-20201217.0.x86_64.qcow2
  * Centos 8 Overlay (Internal): https://emb-pub.ostc.intel.com/overlay/centos/8/latest/images/centos-8.2.2004-embargo-coreserver-202112310042.img.xz
  * Centos 8 Cluster Image (Internal): http://s3web.l10b2.deacluster.intel.com/qcow2-images/DEV/centos8-Next-Kernel-202012230242-DEV.qcow2 [This is derived from the overlay internal image]

Each of the images have a different way to logging in and launching so kindly follow the steps below to boot the image.
* Ubuntu Focal:
  * Launch qemu with the below command.  
    `qemu-system-x86_64 -enable-kvm -cpu host -bios OVMF.fd -smp sockets=1,cpus=1,cores=2 -m 2048M -vga none -nographic -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 -drive file=focal-server-cloudimg-amd64.img,if=virtio,aio=threads -drive file=cloud-init.img,if=virtio,format=raw`
  * Login with `tester:tester`
* Centos 8 Stream:
  * launch qemu with the below command.  
    `qemu-system-x86_64 -enable-kvm -cpu host  -smp sockets=1,cpus=1,cores=2 -m 2048M -vga none -nographic -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 -drive file=CentOS-Stream-GenericCloud-8-20201217.0.x86_64.qcow2,if=virtio,aio=threads -drive file=cloud-init.img,if=virtio,format=raw`  
    *Note: We are not using the bios to boot this image*
  * Login with `tester:tester`
* Centos 8 Overlay:
  * Launch qemu with the below command.  
    `qemu-system-x86_64 -enable-kvm -cpu host -bios OVMF.fd -smp sockets=1,cpus=1,cores=2 -m 2048M -vga none -nographic -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 -drive file=centos-8.2.2004-embargo-coreserver-202112310042.img=,if=virtio,aio=threads`
  * Login with `root:` [Note: Empty password]
* Centos 8 Cluster Image:
  * Launch qemu with the below command.  
    `qemu-system-x86_64 -enable-kvm -cpu host -bios OVMF.fd -smp sockets=1,cpus=1,cores=2 -m 2048M -vga none -nographic -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 -drive file=centos8-Next-Kernel-202012230242-DEV.qcow2,if=virtio,aio=threads`
  * Login with `root:c1oudc0w`

* Follow the corresponding steps to install the kernel and validate reboot.

## Cloud-init
We are using cloud-init to provision the two upstream images (ubuntu and centos). The way the image was created is described below.
* `user-data` and `meta-data` file are available in this repository. Please review them.
* use cloud tools to create the image.
  * `cloud-localds cloud-init.img user-data meta-data` [This works on ubuntu, fedora. has not been tested in centos yet]

# Sanity checks

This is highly specific to the committed state of the provisioning script, and
assumes each target node's Host OS is Clear Linux. If you have heavily modified
it, or if the cluster Host OS has changed, this section will be largely
irrelevant.

/etc/udev/rules.d should have a file in it

/usr/lib/kernel should have your kernel version modules in it

/boot (mount /dev/nvme0n1p1 /boot) should have your kernel version vmlinuz,
System.map, and config in it

/boot/loader/loader.conf 's "default" line should point to your kernel
version's entry

/boot/loader/entries 's new entry should not specify a root UUID or PARTUUID,
rather an absolute rootfs (/dev/nvme0n1p3)
