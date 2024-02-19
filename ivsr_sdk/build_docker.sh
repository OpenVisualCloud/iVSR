#!/bin/sh
set -e

OV_VERSION="ov2022.3"
TAG=$(git rev-parse --short HEAD)

if [ ! -z "$1" ]; then
	OV_VERSION=$1
	echo "ov version $OV_VERSION"
fi

if [ ! -z "$2" ]; then
	TAG=$2
	echo "docker tag $TAG"
fi

sudo docker build --build-arg http_proxy=$http_proxy \
 	--build-arg https_proxy=$https_proxy \
	--build-arg no_proxy=$no_proxy \
	--build-arg UBUNTU_VERSION=22.04 \
	--build-arg PYTHON=python3.10 \
	--build-arg ICD_VER=22.49.25018.23+i554~22.04 \
	--build-arg LEVEL_ZERO_GPU_VER=1.3.25018.23+i554~22.04 \
	--build-arg LEVEL_ZERO_VER=1.8.8+i524~u22.04 \
	--build-arg LEVEL_ZERO_DEV_VER=1.8.8+i524~u22.04 \
	-f $OV_VERSION.dockerfile -t ivsr_sdk_$OV_VERSION:$TAG \
	..
