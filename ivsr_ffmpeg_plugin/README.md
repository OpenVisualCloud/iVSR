# iVSR FFmpeg plugin - iVSR SDK based
The folder `ivsr_ffmpeg_plugin` enables model inference using FFmpeg with iVSR SDK as backend.
The inference is validated with OpenVINO 2022.3/2023.2 and FFmpeg 6.1. We've implemented some patches on the OpenVINO and FFmpeg to enable the pipeline. The folder patches includes our patches for FFmpeg.

<div align=center>
<img src="./figs/ffmpeg_ivsr_sdk_backend.png" width = 80% height = 80% />
</div>

## Prerequisites
- Intel Xeon hardware platform
- Intel Data Center GPU Flex 170(*aka* ATS-M1 150W)
- Host OS: Linux based OS (Ubuntu 22.04)
- Docker OS: Ubuntu 22.04
- kernel: 5.17.0-1031-oem (Optional, only required to enable Intel® Data Center GPU Flex Series accelerator)
- cmake
- make
- git
- docker 

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
cd ivsr_ffmpeg_plugin
./build_docker.sh --enable_ov_patch [true|false] --ov_version [2022.3|2023.2]
```
Currently ivsr support OpenVINO 2022.3 and 2023.2, but only OpenVINO 2022.3 version supports Enhanced BasicVSR model and need to apply some patches to support the model.
`--enable_ov_patch` to set true/flase to enable/disable apply pacthes of OpenVINO 2022.3 which are required to support Enhanced BasicVSR model, `--ov_version` to set OpenVINO version to 2022.3 or 2023.2.
If building successfully, you can see a docker image named `ffmpeg_ivsr_sdk_ov2022.3` or `ffmpeg_ivsr_sdk_ov2023.2` .

## Start Docker Container

```bash
sudo docker run -itd --name ffmpeg_ivsr_sdk --privileged -e MALLOC_CONF="oversize_threshold:1,background_thread:true,metadata_thp:auto,dirty_decay_ms:9000000000,muzzy_decay_ms:9000000000" -e http_proxy=$http_proxy -e https_proxy=$https_proxy -e no_proxy=$no_proxy --shm-size=128g --device=/dev/snd:/dev/snd ffmpeg_ivsr_sdk_[ov2022.3|ov2023.2]:latest bash
sudo docker exec -it ffmpeg_ivsr_sdk bash
/workspace/ivsr/ivsr_ov/based_on_openvino_[2022.3|2023.2]/openvino/install/setupvars.sh
ldconfig
```
## How to run inference with FFmpeg-plugin
- Use FFmpeg-plugin to run Enhanced BasicVSR inference, needs to set extension and op_xml options to run Enhanced BasicVSR model
```
cd /workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=<basic_vsr_model.xml>:input=input:output=output:nif=3:backend_configs='device=<CPU or GPU>&extension=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so&op_xml=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml' test_out.mp4
```
- Use FFmpeg-plugin to run SVP models inference
```
cd /workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=<svp_model.xml>:input=input:output=output:nif=1:backend_configs='device=<CPU or GPU>&model_type=1' test_out.mp4
```
- Use FFmpeg-plugin to run Enhanced EDSR inference
```
cd /workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=<edsr_model.xml>:input=input:output=output:nif=1:backend_configs='device=<CPU or GPU>&model_type=2&normalize_factor=255.0' test_out.mp4
```
- Use FFmpeg-plugin to run TSENet model
```
cd /workspace/ivsr/ivsr_ffmpeg_plugin/based_on_ivsr_sdk_backend/ffmpeg
./ffmpeg -i <your test video> -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=<tsenet_model.xml>:input=input:output=output:nif=1:backend_configs='device=<CPU or GPU>&model_type=4' test_out.mp4
```

- Work modes of FFmpeg-plugin

Decoder and encoder work similar to FFmpeg. Options and command line formats are not changed.
Only the options of video filter `dnn_processing` are introduced.

|AVOption name|Description|Default value|Recommended value(s)|
|:--|:--|:--|:--|
|dnn_backend|DNN backend framework name|native|ivsr|
|model|path to model file|NULL|Available full path of the released model files|
|input|input name of the model|NULL|input|
|output|output name of the model|NULL|output|
|backend_configs:device|device for inference task|CPU|CPU or GPU|
|backend_configs:model_type|type for models|0|0 for Enhanced BasicVSR, 1 for SVP models, 2 for Enhanced EDSR, 3 for one CUSTOM VSR, 4 for TSENet|
|backend_configs:normalize_factor|factor for normalization|1.0|255.0 for Enhanced EDSR, 1.0 for other models supported in current version|
|backend_configs:extension|extension lib file full path, required for loading Enhanced BasicVSR model|
|backend_configs:op_xml|custom op xml file full path, required for loading Enhanced BasicVSR model|
|nif|number of input frames in batch sent to the DNN backend|1|3 for Enhanced BasicVSR, 1 for other models supported in current version|

Apart from the common AVOptions which can be set in the normal FFmpeg command line with format `AVOption=value`, there are several other options `device`, `model_type`, and `normalize_factor` to be set with the `backend_configs` option. The command format is `backend_configs='device=value:model_type=value:normalize_factor=value'` when you want to set them.

- OpenVINO custom operations support for Enhanced BasicVSR model

The [Custom OpenVINO™ Operations](https://docs.openvino.ai/latest/openvino_docs_Extensibility_UG_add_openvino_ops.html) is a great feature of OpenVINO which allows users to support models with custom operations that OpenVINO does not support out-of-the-box.
This FFmpeg-plugin supports Enhanced BasicVSR model which utilizes custom operations. It requires to set extension and op_xml options (with `backend_configs`) in command line to run Enhanced BasicVSR model. The extension lib file is located in docker container folder `/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so` and the op xml file is located in docker container folder `/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml`. And please note that the libcustom_extension.so and flow_warp.xml are generated during the build of OpenVINO after apply OpenVINO's patches.
