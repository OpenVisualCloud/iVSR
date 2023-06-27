# iVSR GPU Optimization for OpenVINO 2022.3

This folder `based_on_openvino_2022.3` enables BasicVSR inference on Intel CPU/GPU using OpenVINO 2022.3 as backend.

## Prerequisites:
- Intel Xeon hardware platform 
- (Optional) Intel Data Center GPU Flex 170(*aka* ATS-M1 150W)
- Host OS: Linux based OS (Ubuntu 22.04)
- Docker OS: Ubuntu 22.04
- kernel: 5.15.0-72-generic
- cmake 
- make
- git
- [docker](https://www.docker.com)

## Build Docker Image
You can quickly create a docker image with the ready-to-use OpenVINO environment by executing `build_docker.sh`. The default docker image name is `ivsr_gpu_opt`.

The detailed steps to enable GPU can be referenced to [ivsr_SDK GPU Enabling](https://github.com/intel-innersource/applications.services.cloud.visualcloud.video-processing.ivsr/blob/dev/ivsr_sdk/README.md#install-gpu-driver).

The detailed steps to build docker image can be referenced to [ivsr_SDK Build Docker Image](https://github.com/intel-innersource/applications.services.cloud.visualcloud.video-processing.ivsr/blob/dev/ivsr_sdk/README.md#build-docker-image).

## Start Docker Container 
```bash
sudo docker run -itd --name ivsr_gpu_opt --privileged -e MALLOC_CONF="oversize_threshold:1,background_thread:true,metadata_thp:auto,dirty_decay_ms:9000000000,muzzy_decay_ms:9000000000" -e http_proxy=$http_proxy -e https_proxy=$https_proxy -e no_proxy=$no_proxy --shm-size=128g --device=/dev/snd:/dev/snd    ivsr_sdk:latest bash
sudo docker exec -it ivsr_gpu_opt bash
```

## BasicVSR Inference Sample
There is a C++ sample to perform BasicVSR inference on OpenVINO backend. You can reach the sample code and the executable file after you have built the docker image and started the docker container successfully. 

You can run `/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/Release -h` to get help messages and see the default settings of parameters. 

|Option name|Desciption|Default value|Recommended value(s)|
|:--|:--|:--|:--|
|h|Print Help Message|||
|cldnn_config|Need. Path of CLDNN config.|None|< Path to OpenVINO >/flow_warp_custom_op/flow_warp.xml|
|data_path|Need. Input data path for inference.|None||
|device|Optional. Device to perform inference.|CPU|CPU or GPU|
|extension|Optional. Extension (.so or .dll) path of custom operation.|None|< Path to basicvsr_sample>/lib/libcustom_extension.so|
|model_path|Need. Path of BasicVSR OpenVINO IR model (.xml).|None||
|nif|Need. Number of input frames for each inference.|3|3|
|save_path|Optional. Path to save predictions.|./outputs||
|save_predictions|Optional. Whether to save the results to save_path.||If this option exists, results will be saved.|

Please note that all the pathes specified options should exist and do not end up with '/'. Here are some examples to run BasicVSR inference:
```bash
# Run the inference evaluation on CPU
/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/basicvsr_sample -model_path=<IR model path(.xml)> -extension=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/lib/libcustom_extension.so -data_path=<Directory path including input frames> -nif=<Number of input frames> -device=CPU -save_predictions -save_path=<Directory path to save results> -cldnn_config=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/flow_warp_custom_op/flow_warp.xml

# Run the inference evaluation on GPU
/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/basicvsr_sample -model_path=<IR model path(.xml)> -extension=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/lib/libcustom_extension.so -data_path=<Directory path including input frames> -nif=<Number of input frames> -device=GPU -save_predictions -save_path=<Directory path to save results> -cldnn_config=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/flow_warp_custom_op/flow_warp.xml
```


