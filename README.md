# What is iVSR

iVSR aims to facilitate AI media processing with exceptional quality and performance on Intel's hardware.

iVSR offers a patch-based, heterogeneous, multi-GPU, and multi-algorithm solution, 
harnessing the full capabilities of Intel's CPUs and GPUs. 
And iVSR is adaptable for deployment on a single device, a distributed system, cloud infrastructure, edge cloud, or K8S environment.

<!-- ![overview](./docs/figs/iVSR.png) -->
<div align=center>
<img src="./docs/figs/iVSR.png" width = 75% height = 75% />
</div>

# Why is iVSR needed

- Simple APIs are provided and the change of OpenVINO API will not be exposed.
- Patch-based solution is provided to enable the inference on HW with limited memory. For example, the SR of super-large-resolution input video, such as 4K.
- Features are provided to protect Intel created AI models which have Intel IP.
- All kinds of AI media processing algorithms can be accommodated under iVSR SDK.
- Performance optimization can be implemented for a specific algorithm to better meet customers’ needs.

# What can iVSR do
Now iVSR has two AI media processing functionalities: video super resolution (VSR) and smart video processing (SVP) for bandwidth optimization.
Inference can be run on both Intel CPU and Intel GPUs (including Flex170, Arc770) with OpenVINO and FFmpeg.


## Video Super Resolution (VSR)

Video super resolution (VSR) is widely used in AI media enhancement domain to 
convert low-resolution video to high-resolution.
iVSR supports Enhanced BasicVSR, Enhanced EDSR, TSENet, and can also be updated to support other models.

#### `Enhanced BasicVSR`
BasicVSR is a public AI-based VSR algorithm. 
For the details of public BasicVSR, please check the [paper](https://arxiv.org/pdf/2012.02181.pdf). 

We have enhanced the public model to achieve better visual quality and less computational complexity. 
The performance of BasicVSR inference has also been optimized for Intel GPU.


#### `Enhanced EDSR`
EDSR is another public AI-based single image SR algorithm.
For the details of public EDSR, please check the [paper](https://arxiv.org/pdf/1707.02921.pdf)

We have enhanced the public EDSR model to reduce the computational complexity by over 79% compared to Enhanced BasicVSR, while achieving similar visual quality.

#### `TSENet`
TSENet is one multi-frame SR algorithm derived from [ETDS](https://github.com/ECNUSR/ETDS).

It provides pre-view version of feature to support this model in the SDK and its plugin. Please ping Intel representative to get the model package.

## Smart Video Processing (SVP)
`SVP` is an AI-based video prefilter that enhances the perceptual rate-distortion in video encoding. 
With SVP, the encoded video streams achieve reduced bandwidth while maintaining the same visual quality, 
as measured by common video quality metrics (such as VMAF and (MS-)SSIM) and human perception.

# How to use iVSR

There are three ways to run the above AI media processing.
Please expect `pre-production` quality of current solution.

### 1. Run with iVSR SDK sample
Refer to the guide [here](ivsr_sdk/README.md).

### 2. Run with FFmpeg
#### 2.1 Run with FFmpeg in Docker container
Refer to the guide [here](ivsr_ffmpeg_plugin/README.md).
#### 2.2 Run with FFmpeg using host environment
- Create python virtual environment
    ```bash
    sudo apt --fix-broken install
    sudo apt install python3.10-venv
    python3 -m venv ivsr_venv
    source ./ivsr_venv/bin/activate
    ```
- Build ivsr environment in host & Set environment variables
    ```bash
    sudo ./build_ivsr.sh --enable_ov_patch <true/false> --enable_compile_ffmpeg true --ov_version <2022.3|2023.2>
    source ./ivsr_setupvar.sh --ov_version <2022.3|2023.2>
    ```
    If you want to run Enhanced BasicVSR model, must set `--enable_ov_patch true` && `--ov_version 2022.3`.

- How to run inference with FFmpeg-plugin
    - Use FFmpeg-plugin to run Enhanced BasicVSR inference, needs to set extension and op_xml options to run Enhanced BasicVSR model
        ```
        cd <your project folder>/workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
        ./ffmpeg -i <your test video> -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=<basic_vsr_model.xml>:input=input:output=output:nif=3:backend_configs='device=<CPU or GPU>&extension=<your project folder>/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so&op_xml=<your project folder>/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml' test_out.mp4
        ```
    - Use FFmpeg-plugin to run SVP inference
        ```
        cd <your project folder>/workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
        ./ffmpeg -i <your test video> -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=<svp_model.xml>:input=input:output=output:nif=1:backend_configs='device=<CPU or GPU>&model_type=1' test_out.mp4
        ```
    - Use FFmpeg-plugin to run Enhanced EDSR inference
        ```
        cd <your project folder>/workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
        ./ffmpeg -i <your test video> -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=<edsr_model.xml>:input=input:output=output:nif=1:backend_configs='device=<CPU or GPU>&model_type=2&normalize_factor=255.0' test_out.mp4
        ```
    - Use FFmpeg-plugin to run CUSTOM VSR inference
        ```
        cd <your project folder>/workspace/ivsr/
        ./ffmpeg -i <your test video> -vf format=yuv420p,dnn_processing=dnn_backend=ivsr:model=<customvsr_model.xml>:input=input:output=output:nif=1:backend_configs='nireq=1&device=CPU&model_type=3' test_out.mp4
        ```
    - Use FFmpeg-plugin to run TSENet model
        ```
        cd <your project folder>/workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
        ./ffmpeg -i <your test video> -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=<tsenet_model.xml>:input=input:output=output:nif=1:backend_configs='device=<CPU or GPU>&model_type=4' test_out.mp4
        ```


Please [contact us](mailto:beryl.xu@intel.com) to get the models.

## License

Please check the license under each folder.

