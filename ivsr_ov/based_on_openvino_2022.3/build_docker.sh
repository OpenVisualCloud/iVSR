#!/bin/sh
git submodule update --init ./openvino
cd openvino
git submodule update --init --recursive
git checkout 2022.3.0

cp ../patches/*.patch ./
for patch_file in $(find -iname "*.patch" | sort -n);
do
    echo "Applying: ${patch_file}";
    git am --whitespace=fix ${patch_file};
done

cd ..
sudo docker build --build-arg http_proxy=$http_proxy \
 	--build-arg https_proxy=$https_proxy \
	--build-arg no_proxy=$no_proxy \
	--build-arg UBUNTU_VERSION=22.04 \
	--build-arg PYTHON=python3.10 \
	--build-arg ICD_VER=22.49.25018.23+i554~22.04 \
	--build-arg LEVEL_ZERO_GPU_VER=1.3.25018.23+i554~22.04 \
	--build-arg LEVEL_ZERO_VER=1.8.8+i524~u22.04 \
	--build-arg LEVEL_ZERO_DEV_VER=1.8.8+i524~u22.04 \
	--network=host \
        -f Dockerfile -t ivsr_ov \
	.
