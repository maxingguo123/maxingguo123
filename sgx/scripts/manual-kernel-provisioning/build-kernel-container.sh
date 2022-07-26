#!/bin/bash
#
# Create container to build kernels for test in clusters
# Author: Ganesh Maharaj Mahalingam <ganesh.mahalingam@intel.com>
#

set -o errexit
set -o nounset

: "${UBUNTU_CONT:="ubuntu-kernel-builder"}"
: "${CENTOS_CONT:="centos-kernel-builder"}"
KERNEL_PATH=""
DISTRO=""

function usage()
{
  echo ""
  echo "Usage: ${0} [-d | --distro ] [-k | --kernelpath ] [-h | --help ]"
  echo ""
  echo "d|distro: Distro to base the container on"
  echo "   Current options: ubuntu, centos"
  echo "k|kernelpath: Path on the host with the kernel sources"
  echo "h|help: print this"
  echo ""
  exit 1
}

function create_ubuntu_container()
{
  local CONT=${UBUNTU_CONT}
  if docker ps -a | grep -q ${CONT}; then
    docker rm -f ${CONT}
  fi
  docker run -itd --privileged -v ${KERNEL_PATH}:${KERNEL_PATH}:rw -h ${CONT} --name ${CONT} ubuntu:20.04
  docker exec -it ${CONT} apt update
  docker exec -it ${CONT} apt install -y \
    autoconf \
    bc \
    bison \
    cpio \
    dkms \
    flex \
    git \
    libelf-dev \
    libiberty-dev \
    libncurses-dev \
    libpci-dev \
    libssl-dev \
    libudev-dev \
    openssl \
    rsync
  echo "${CONT} ready to build kernel"
}

function create_centos_container()
{
  local CONT=${CENTOS_CONT}
  if docker ps -a | grep -q ${CONT}; then
    docker rm -f ${CONT}
  fi
  docker run -itd --privileged -v ${KERNEL_PATH}:${KERNEL_PATH}:rw -h ${CONT} --name ${CONT} centos:centos8
  docker exec -it ${CONT} dnf update -y
  docker exec -it ${CONT} dnf groupinstall -y "Development Tools"
  docker exec -it ${CONT} dnf install -y \
    bc \
    binutils-devel \
    elfutils-libelf-devel \
    hmaccalc \
    ncurses-devel \
    openssl-devel \
    rsync \
    zlib-devel
  echo "${CONT} ready to build kernel"
}

ARGS=$(getopt -o d:k:h -l distro:,kernelpath:,help -- "$@");
if [ $? -ne 0 ];then usage; fi
eval set -- "$ARGS"

while true; do
  case "$1" in
    -d|--distro) DISTRO="$2"; shift 2;;
    -k|--kernelpath) KERNEL_PATH="$2"; shift 2;;
    -h|--help) usage;;
    --) shift; break;;
    *) usage;;
  esac
done

if [ -z $DISTRO ] || [ -z $KERNEL_PATH ]; then
  echo "Missing either ditro or the kernel path"
  exit 1
fi

if ! [[ ${DISTRO} =~ ^(ubuntu|centos)$ ]]; then
  echo "Unsupported distro. Current suported distros are"
  echo "ubuntu, centos"
  exit 1
fi

create_${DISTRO}_container
