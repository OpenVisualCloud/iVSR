# Enhanced BasicVSR (iVSR)

Video super resolution (VSR) is widely used in AI media enhancement domain to 
convert low-resolution video to high-resolution. 


BasicVSR is a public AI-based VSR algorithm. 
For details of public BasicVSR, check out the [paper](https://arxiv.org/pdf/2012.02181.pdf). 

We have enhanced the public model to achieve better visual quality and less computational complexity. 
The performance of BasicVSR inference has also been optimized for Intel GPU. 
Now, 2x Enhanced BasicVSR can be run on both Intel CPU and Intel Data Center GPU Flex 170 (*aka* ATS-M1 150W) with OpenVINO and FFmpeg.

We also provide iVSR SDK which aims to provide a patch-based, heterogeneous, multi-GPU and multi-algo VSR solution with 
great quality and performance.


## How to evaluate

Please expect `pre-production` quality of current solution.

### Get models
Please [contact us](mailto:yanjie.pan@intel.com) for FP32/INT8 Enhanced BasicVSR models. Will provide links to download the models soon.

### Run with iVSR SDK
Refer to the guide [here](ivsr_sdk/README.md).

### Run with OpenVINO
Refer to the guide [here](ivsr_gpu_opt/README.md).

### Run with FFmpeg
Refer to the guide [here](ivsr_ffmpeg_plugin/README.md).


## License

Please check the license under each folder.

