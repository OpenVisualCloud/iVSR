<!-- ![logo](./docs/figs/iVSR.png) -->
<div align=center>
<img src="./docs/figs/logo.png" width = 20% height = 20% />
</div>

<div align=center>

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/OpenVisualCloud/iVSR/badge)](https://api.securityscorecards.dev/projects/github.com/OpenVisualCloud/iVSR)
[![OpenSSF Best Practices](https://bestpractices.coreinfrastructure.org/projects/9795/badge)](https://bestpractices.coreinfrastructure.org/projects/9795)
[![Dependency Review](https://github.com/OpenVisualCloud/iVSR/actions/workflows/dependency-review.yml/badge.svg)](https://github.com/OpenVisualCloud/iVSR/actions/workflows/dependency-review.yml)
[![CodeQL](https://github.com/OpenVisualCloud/iVSR/actions/workflows/codeql.yml/badge.svg)](https://github.com/OpenVisualCloud/iVSR/actions/workflows/codeql.yml)  
[![License](https://img.shields.io/badge/license-BSD_3_Clause-stable.svg)](https://github.com/OpenVisualCloud/iVSR/blob/master/LICENSE.md)
[![Contributions](https://img.shields.io/badge/contributions-welcome-blue.svg)](https://github.com/OpenVisualCloud/iVSR/wiki)
[![Ubuntu-DockerFile-Build](https://github.com/OpenVisualCloud/iVSR/actions/workflows/ubuntu-build-docker.yml/badge.svg)](https://github.com/OpenVisualCloud/iVSR/actions/workflows/ubuntu-build-docker.yml)
[![Trivy](https://github.com/OpenVisualCloud/iVSR/actions/workflows/trivy.yml/badge.svg)](https://github.com/OpenVisualCloud/iVSR/actions/workflows/trivy.yml)
</div>

# Contents Overview
1. [Overview of iVSR](#1-overview-of-ivsr)
    - [What is iVSR](#11-what-is-ivsr)
    - [Why is iVSR needed](#12-why-is-ivsr-needed)
    - [iVSR Components](#13-ivsr-components)
    - [Capabilities of iVSR](#14-capabilities-of-ivsr)
2. [Setup iVSR env on linux](#2-setup-ivsr-env-on-linux)
    - [Install GPU kernel packages(Optional)](#21-optional-install-gpu-kernel-packages)
    - [Install dependencies and build iVSR manually](#22-install-dependencies-and-build-ivsr-manually)
    - [Install dependencies and build iVSR by scripts](#23-install-dependencies-and-build-ivsr-by-scripts)
    - [Install dependencies and build iVSR by Dockerfile](#24-install-dependencies-and-build-ivsr-by-dockerfile)
3. [How to use iVSR](#3-how-to-use-ivsr)
    - [Run with iVSR SDK sample](#31-run-with-ivsr-sdk-sample)
    - [Run with FFmpeg](#32-run-with-ffmpeg)
4. [Model files](#4-model-files)
5. [License](#5-license)
# 1. Overview of iVSR
## 1.1 What is iVSR
iVSR facilitates AI media processing with exceptional quality and performance on Intel hardware.

iVSR offers a patch-based, heterogeneous, multi-GPU, and multi-algorithm solution, harnessing the full capabilities of Intel CPUs and GPUs. It is adaptable for deployment on a single device, a distributed system, cloud infrastructure, edge cloud, or K8S environment.

<!-- ![overview](./docs/figs/iVSR.png) -->
<div align=center>
<img src="./docs/figs/iVSR.png" width = 75% height = 75% />
</div>

## 1.2 Why is iVSR needed

- Simple APIs ensure that any changes to the OpenVINO API remain hidden.
- A patch-based solution facilitates inference on hardware with limited memory capacity, particularly useful for super-resolution of high-resolution input videos, such as 4K.
- The iVSR SDK includes features to safeguard AI models created by Intel, which contain Intel IP.
- The iVSR SDK is versatile and supports a wide range of AI media processing algorithms.
- For specific algorithms, performance optimization can be executed to better align with customer requirements.

## 1.3 iVSR Components
This repository or package includes the following major components:

### 1.3.1 iVSR SDK
The iVSR SDK is a middleware library that supports various AI video processing filters. It is designed to accommodate different AI inference backends, although currently, it only supports OpenVINO.<br>
For a detailed introduction to the iVSR SDK API, please refer to [this introduction](./ivsr_sdk/README.md#api-introduction).

We've also included a `vsr_sample` as a demonstration of its usage.

In order to support the widely-used media processing solution FFmpeg, we've provided an iVSR SDK plugin to simplify integration.<br>
This plugin is integrated into FFmpeg's `dnn_processing` filter in the [FFmpeg documentation](https://ffmpeg.org/ffmpeg-filters.html#dnn_005fprocessing-1) in the libavfilter library, serving as a new `ivsr` backend to this filter. Please note that the patches provided in this project are specifically for FFmpeg n7.1.<br>

### 1.3.3 OpenVINO patches and extension
In [this folder](./ivsr_ov/based_on_openvino_2022.3/patches), you'll find patches for OpenVINO that enable the Enhanced BasicVSR model. These patches utilize OpenVINO's [Custom OpenVINO™ Operations](https://docs.openvino.ai/2024/documentation/openvino-extensibility/custom-openvino-operations.html) feature, which allows users to support models with custom operations not inherently supported by OpenVINO.<br>
These patches are specifically for OpenVINO 2022.3, meaning the Enhanced BasicVSR model will only work on OpenVINO 2022.3 with these patches applied.<br>

## 1.4 Capabilities of iVSR
Currently, iVSR offers two AI media processing functionalities: Video Super Resolution (VSR) and Smart Video Processing (SVP) for bandwidth optimization. Both functionalities can be run on Intel CPUs and Intel GPUs (including Flex170, Arc770) via OpenVINO and FFmpeg.

### 1.4.1 Video Super Resolution (VSR)
Video Super Resolution (VSR) is a technique extensively employed in the AI media enhancement domain to upscale low-resolution videos to high-resolution. iVSR supports `Enhanced BasicVSR`, `Enhanced EDSR`, and `TSENet`. It also has the capability to be extended to support additional models.

- #### i. Enhanced BasicVSR
  `BasicVSR` is a publicly available AI-based VSR algorithm. For more details on the public `BasicVSR`, please refer to this [paper](https://arxiv.org/pdf/2012.02181.pdf).<br><br>
  We have improved the public model to attain superior visual quality and reduced computational complexity. This improved model is named `Enhanced BasicVSR`. The performance of the `Enhanced BasicVSR` model inference has also been optimized for Intel GPUs. Please note that this optimization is specific to OpenVINO 2022.3. Therefore, the Enhanced BasicVSR model only works with OpenVINO 2022.3 with the applied patches.<br><br>
  The input shape of this model and the output shape are:
  ```plaintext
  Input shape: [1, (channels)3, (frames)3, H, W]
  Output shape: [1, (channels)3, (frames)3, 2xH, 2xW]
  ```

- #### ii. Enhanced EDSR
  `EDSR` is another publicly available AI-based single image SR algorithm. For more details on the public EDSR, please refer to this [paper](https://arxiv.org/pdf/1707.02921.pdf)<br><br>
  We have improved the public `EDSR` model to reduce the computational complexity by over 79% compared to Enhanced BasicVSR. This improvement maintains similar visual quality and is named `Enhanced EDSR`.<br><br>
  The input shape of this model and the output shape are:
  ```plaintext
  Input shape: [1, (channels)3, H, W]
  Output shape: [1, (channels)3, 2xH, 2xW]
  ```

- #### iii. TSENet
  `TSENet` is one multi-frame SR algorithm derived from [ETDS](https://github.com/ECNUSR/ETDS).<br><br>
  We provide a preview version of the feature to support this model in the SDK and its plugin. Please contact your Intel representative to obtain the model package.<br><br>
  The input shape of this model and the output shape are:
  ```plaintext
  Input shape: [1, (channels * frames)9, H, W]
  Output shape: [1, (channels)3, 2xH, 2xW]
  ```
  For each inference, the input data is the `(n-1)th`, `(n)th`, and `(n+1)th` frames combined. The output data is the `(N)th` frame. For the first frame, the input data is `1st`, `1st`, `2nd` frames combined. For the last frame, the input data is the `(n-1)th`, `(n)th`, `(n)th` frames combined.

### 1.4.2. Smart Video Processing (SVP)
`SVP` is an AI-based video prefilter that enhances perceptual rate-distortion in video encoding. With `SVP`, encoded video streams maintain the same visual quality while reducing bandwidth usage.<br>

Two SVP model variants are provided:

- **SVP-Basic**: This model is designed for efficiency, preserving fidelity while reducing the encoded bitrate. Modifications made by SVP-Basic are imperceptible to the human eye but can be measured by minor BD-rate degradation when evaluated using SSIM or MS-SSIM metrics. SVP-Basic is adaptable to various video scenarios, including live sports, gaming, livestream sales, VOD, video conferencing, video surveillance, and 5G video streaming.<br>

- **SVP-SE**: This model focuses on subjective video quality preservation, achieving up to 50% bitrate savings. It enhances visuals by reducing complex details and noise that are less perceptible to human eyes. As a result, it cannot be evaluated by traditional full-reference visual quality metrics like PSNR, SSIM, or VMAF. SVP-SE improves the visibility and quality of visuals, making them more vivid and appealing, which is beneficial in industries such as entertainment, media, and advertising.<br>

The input and output shapes are:
- RGB based model: 
  ```plaintext
  Input shape: [1, (channels)3, H, W]
  Output shape: [1, (channels)3, H, W]
  ```
- Y based model:
  ```plaintext
  Input shape: [1, (channels)1, H, W]
  Output shape: [1, (channels)1, H, W]
  ```
<br>

# 2. Setup iVSR env on linux
The software was validated on:
- Intel Xeon hardware platform
- (Optional) Intel® Data Center GPU Flex 170(*aka* ATS-M1 150W)
- Host OS: Linux-based OS (Ubuntu 22.04 or Rocky Linux 9.3)
- Docker-based OS: Ubuntu 22.04 or Rocky Linux 9.3
- OpenVINO: [2022.3](https://github.com/openvinotoolkit/openvino/tree/2022.3.0), [2023.2](https://github.com/openvinotoolkit/openvino/tree/2023.2.0), or [2024.5](https://github.com/openvinotoolkit/openvino/tree/2024.5.0)
- FFmpeg: [n7.1](https://github.com/FFmpeg/FFmpeg/tree/n7.1)

Building iVSR requires the installation of the GPU driver (optional), OpenCV, OpenVINO, and FFmpeg.  
We provide **three** ways to install requirements and build iVSR SDK & iVSR FFmpeg plugin:<br>
1. [Install dependencies and build iVSR manually](#22-install-dependencies-and-build-ivsr-manually)<br>
2. [Install dependencies and build iVSR by scripts](#23-install-dependencies-and-build-ivsr-by-scripts)<br>
3. [Install dependencies and build iVSR by Dockerfile](#24-install-dependencies-and-build-ivsr-by-dockerfile)<br>

Note that to run inference on a **GPU**, it is necessary to have **kernel packages** installed on the bare metal system beforehand. See [Install GPU kernel packages](#21-optional-install-gpu-kernel-packages) for details.<br>

## 2.1 (Optional) Install GPU kernel packages
Refer to this [instruction](https://dgpu-docs.intel.com/driver/installation.html#ubuntu-package-installation) for the installation guide on Ubuntu. GPU runtime driver/packages are also installed in script and dockerfile provided.

## 2.2 Install dependencies and build iVSR manually

Here are two guides for your reference:<br>
1. **Generic Manual Building Guide**: If you are familiar with Intel® devices and have experience with Intel® developed software, follow the official steps to build OpenCV and OpenVINO from source code. Refer to the [Generic manual building guide](docs/generic_manual_build.md#generic-manual-build-steps-for-ffmpeg--ivsr-plugin-software).<br>
2. **Quick Manual Building Guide**: For absolute beginners, this tutorial provides step-by-step instructions to build the project on a clean Ubuntu OS. Refer to the [Quick manual building guide](docs/quick_try_manual_build.md#manual-build-steps-for-ffmpeg--ivsr-plugin-software-on-ubuntu).<br>

## 2.3 Install dependencies and build iVSR using scripts
We provide a `build.sh` script to facilitate building the entire project from source on a clean Ubuntu 22.04-based Linux machine.

```bash
chmod a+x ./build.sh
./build.sh --ov_version [2022.3|2023.2|2024.5]
```

The script accepts the following parameter:
- `ov_version`: Specifies the OpenVINO version. iVSR supports `2022.3`, `2023.2`, and `2024.5`. Note that running the Enhanced BasicVSR model requires `2022.3`.

After the build is complete, set the environment variables. For OpenVINO 2022.3:

```bash
source <workspace>/ivsr_ov/based_on_openvino_2022.3/openvino/install/setupvars.sh
```

For other OpenVINO versions installed via official packages, manual environment setup is not required.

Once the build is successfully completed, refer to [section 3.2](#32-run-with-ffmpeg) for instructions on using the FFmpeg command line to run the pipelines. Feel free to modify and update these scripts as needed. For newly released OpenVINO versions, please follow the [manual build](#22-install-dependencies-and-build-ivsr-manually) guide.

## 2.4 Install dependencies and build iVSR using Dockerfile
To simplify the environment setup, Dockerfiles are provided. Follow the [Docker image build guide](docs/docker_image_build.md#docker-image-build-guide) to build the Docker image and run the application in Docker containers.

# 3. How to use iVSR
You can run inference on the iVSR SDK using either the `vsr_sample` or the `ffmpeg` integrated with the iVSR plugin. Before running them, set up the environment with the following commands:
```bash
source <OpenVINO installation dir>/install/setupvars.sh
export LD_LIBRARY_PATH=<Package dir>/ivsr_sdk/lib:<OpenCV installation folder>/install/lib:$LD_LIBRARY_PATH
```
Note that the current solution is of `pre-production` quality.

## 3.1 Run with iVSR SDK sample
The `vsr_sample` is developed using the iVSR SDK and OpenCV. For detailed instructions on running inference with it, refer to this [section](./ivsr_sdk/README.md#vsr-sample).

## 3.2 Run with FFmpeg
After applying the FFmpeg plugin patches and building FFmpeg, refer to [the FFmpeg command line samples](ivsr_ffmpeg_plugin/README.md#how-to-run-inference-with-ffmpeg-plugin) for instructions on running inference with FFmpeg.

# 4. Model files
iVSR supports only models in OpenVINO IR format. Contact your Intel representative to obtain the model files, as they are not included in the repo.

# 5. License
iVSR is licensed under the BSD 3-clause license. See [LICENSE](LICENSE.md) for details.
