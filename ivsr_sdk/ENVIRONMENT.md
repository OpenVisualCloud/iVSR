# Environment Set Up

This document introduces how to set up the environment to build and use the [Intel Video Super Resolution Development Kit](./Introduction.md).

## Prerequisites

- Intel Xeon hardware platform
- (Optional) Intel Data Center GPU Flex 170(*aka* ATS-M1 150W)
- Host OS: Linux based OS (Ubuntu 22.04)
- Docker OS: Ubuntu 22.04
- kernel: 5.15.0-72-generic
- cmake
- make
- git
- [docker](https://www.docker.com)


## Install GPU Driver

### Kernel Update

Our repo is based on kernel 5.15.0-72-generic. Check your original kernel with `uname -r`. If the output is not 5.15.0-72-generic,  run the following steps.

1. Install kernel 5.15.0-72-generic.

   ```bash
   sudo apt-get update
   sudo apt-get install -y --install-suggests linux-image-5.15.0-72-generic
   ```

2. Modify the `GRUB_DEFAULT` in `/etc/default/grub` to set the kernel boot order. Replace `GRUB_DEFAULT=0` with the following line.

   ```shell
   GRUB_DEFAULT='Advanced options for Ubuntu>Ubuntu, with Linux 5.15.0-72-generic'
   ```

3. Update grub configure and reboot.

   ```bash
   sudo update-grub
   sudo reboot
   ```

After rebooting, check the kernel version with `uname -r` again.

Detailed GPU Flex driver installation can be referenced on [https://dgpu-docs.intel.com/driver/installation.html#](https://dgpu-docs.intel.com/driver/installation.html#)



### DKMS Installation

1. Add package repo

```bash
sudo apt-get install -y software-properties-common curl gnupg 
wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
  sudo gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu jammy flex" | \
  sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list
sudo apt-get update
```

2. Install DKMS & header files

```bash
sudo apt-get -y install gawk dkms linux-headers-$(uname -r) libc6-dev
```

3. Install DKMS kernel modules

```bash
sudo apt-get install -y intel-platform-vsec-dkms intel-platform-cse-dkms
sudo apt-get install -y intel-i915-dkms intel-fw-gpu
sudo reboot	
```

If you get problems when installing DKMS, try to remove all the other unused kernels. 



## Build Docker Image
1. Set git config
Please set your git config user.name&email before installation, or our patches will not be applied automatically.

```
git config user.name [your name]
git config user.email [your email]
```

2. Set date&time correctly before building docker image, the following command takes Shanghai as an example.

  ```bash
  timedatectl set-timezone Asia/Shanghai
  ```

3. Set up docker service

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
printf "[Service]\nEnvironment=\"HTTPS_PROXY=$https_proxy\" \"NO_PROXY=$no_proxy\"\n" | sudo tee  /etc/systemd/system/docker.service.d/proxy.conf
sudo systemctl daemon-reload
sudo systemctl restart docker 
```

4. Build docker image

```bash
cd ivsr_sdk/
./build_docker.sh
```

If building successfully, you can see a docker image named `ivsr_sdk` .



## Start Docker Container

```bash
sudo docker run -itd --name ivsr_sdk --privileged -e MALLOC_CONF="oversize_threshold:1,background_thread:true,metadata_thp:auto,dirty_decay_ms:9000000000,muzzy_decay_ms:9000000000" -e http_proxy=$http_proxy -e https_proxy=$https_proxy -e no_proxy=$no_proxy --shm-size=128g --device=/dev/snd:/dev/snd ivsr_sdk:latest bash
sudo docker exec -it ivsr_sdk bash
```


## Run VSR Sample in the Docker Container 

Run the VSR sample `/workspace/ivsr/ivsr_sdk/build/samples/vsr_sample` on different devices with the following commands.

```bash
# VSR sample on CPU
./vsr_sample --model_path=[your model.xml] --data_path=[folder contains low resolution images] --extension=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so --cldnn_config=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml --nig=3 --device=CPU          
# VSR sample on Single GPU
./vsr_sample --model_path=[your model.xml] --data_path=[folder contains low resolution images] --extension=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so --cldnn_config=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml --nig=3 --device=GPU
# VSR sample on Multiple-GPUs
./vsr_sample --model_path=[your model.xml] --data_path=[folder contains low resolution images] --extension=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so --cldnn_config=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml --nig=3 --device=MULTI:GPU.0,GPU.1
```
You can refer to [VSR Sample](./Introduction.md) for more details.



## FAQ

:pushpin: Debconf: unable to initialize frontend: Dialog

Add `ENV DEBIAN_FRONTEND noninteractive` into the Dockerfile under the folder `ivsr_sdk`.

:pushpin: Failed to pull ubuntu22.04 while building docker image 

Check your docker source setting, which is often in `/etc/docker/daemon.json`. You can also take a work around method by running `docker pull ubuntu:22.04`.

:pushpin: Can not connect to repositories when add-apt-repository

May need to add proxy for apt.

```bash
sudo vim /etc/apt/apt.conf.d/proxy.conf
## add proxy 
Acquire::http::Proxy "[your proxy server address]:[your proxy server ip]";
Acquire::https::Proxy "[your proxy server address]:[your proxy server ip]";
```
