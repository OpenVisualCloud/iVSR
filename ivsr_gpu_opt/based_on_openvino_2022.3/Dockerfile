# SPDX-License-Identifier: BSD 3-Clause License
#
# Copyright (c) 2023, Intel Corporation
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

ARG IMAGE=ubuntu:22.04
FROM $IMAGE AS base

RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl wget ca-certificates gpg-agent software-properties-common && \
  rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

FROM base as build
LABEL vendor="Intel Corporation"

RUN mkdir -p /workspace/ivsr

# openvino
RUN apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing \
            apt-utils \
            ca-certificates \
            curl \
            cmake \
            cython3 \
            flex \
            bison \
            gcc \
            g++ \
            git \
            make \
            patch \
            pkg-config \
            wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN no_proxy=$no_proxy wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
    gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg
RUN echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu jammy flex' | \
    tee  /etc/apt/sources.list.d/intel.gpu.jammy.list

#install opencv
ARG WORKSPACE=/workspace
ARG OPENCV_REPO=https://github.com/opencv/opencv/archive/4.5.3-openvino-2021.4.2.tar.gz
RUN cd ${WORKSPACE} && \
  wget -qO - ${OPENCV_REPO} | tar xz

RUN cd ${WORKSPACE}/opencv-4.5.3-openvino-2021.4.2 && mkdir build && mkdir install && cd build && \
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${WORKSPACE}/opencv-4.5.3-openvino-2021.4.2/install \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DOPENCV_GENERATE_PKGCONFIG=ON \
    -DBUILD_DOCS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_TESTS=OFF \
    -DWITH_OPENEXR=OFF \
    -DWITH_OPENJPEG=OFF \
    -DWITH_GSTREAMER=OFF \
    -DWITH_JASPER=OFF \
    .. && \
  make -j "$(nproc)" && \
  make install && \
  cd ${WORKSPACE}/opencv-4.5.3-openvino-2021.4.2/install/bin && bash ./setup_vars_opencv4.sh

ARG ICD_VER
ARG LEVEL_ZERO_GPU_VER
ARG LEVEL_ZERO_VER
ARG LEVEL_ZERO_DEV_VER

RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    intel-opencl-icd=${ICD_VER} \
    intel-level-zero-gpu=${LEVEL_ZERO_GPU_VER} \
    level-zero=${LEVEL_ZERO_VER} \
    level-zero-dev=${LEVEL_ZERO_DEV_VER} && \
    apt-get clean && \
    rm -rf  /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH=${WORKSPACE}/opencv-4.5.3-openvino-2021.4.2/install/lib:$LD_LIBRARY_PATH
ENV OpenCV_DIR=${WORKSPACE}/opencv-4.5.3-openvino-2021.4.2/install/lib/cmake/opencv4
ARG IVSR_DIR=${WORKSPACE}/ivsr
ARG IVSR_OV3_GPU_OPT_DIR=${IVSR_DIR}/ivsr_gpu_opt/based_on_openvino_2022.3/openvino
ARG CUSTOM_OV_INSTALL_DIR=${IVSR_DIR}/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/install

RUN apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            build-essential \
            ca-certificates \
            curl \
            cmake \
            cython3 \
            flex \
            bison \
            gcc \
            g++ \
            git \
            libdrm-dev \
            libudev-dev \
            libtool \
            libusb-1.0-0-dev \
            make \
            patch \
            pkg-config \
            xz-utils \
            ocl-icd-opencl-dev \
            opencl-headers && \
    rm -rf /var/lib/apt/lists/*

ARG PYTHON

RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing \
    ${PYTHON} lib${PYTHON}-dev python3-pip && \
    apt-get clean && \
    rm -rf  /var/lib/apt/lists/*

RUN pip --no-cache-dir install --upgrade \
    pip \
    setuptools

RUN ln -sf $(which ${PYTHON}) /usr/local/bin/python && \
    ln -sf $(which ${PYTHON}) /usr/local/bin/python3 && \
    ln -sf $(which ${PYTHON}) /usr/bin/python && \
    ln -sf $(which ${PYTHON}) /usr/bin/python3

COPY ./openvino $IVSR_OV3_GPU_OPT_DIR
RUN git config --global user.email "noname@example.com" && \
  git config --global user.name "no name" && \
  cd ${IVSR_OV3_GPU_OPT_DIR} && \
  mkdir build && cd build && \
  cmake \
    -DCMAKE_INSTALL_PREFIX=${PWD}/../install \
    -DENABLE_INTEL_CPU=ON \
    -DENABLE_CLDNN=ON \
    -DENABLE_INTEL_GPU=ON \
    -DENABLE_ONEDNN_FOR_GPU=OFF \
    -DENABLE_INTEL_GNA=OFF \
    -DENABLE_INTEL_MYRIAD_COMMON=OFF \
    -DENABLE_INTEL_MYRIAD=OFF \
    -DENABLE_PYTHON=ON \
    -DENABLE_OPENCV=ON \
    -DENABLE_SAMPLES=ON \
    -DENABLE_CPPLINT=OFF \
    -DTREAT_WARNING_AS_ERROR=OFF \
    -DENABLE_TESTS=OFF \
    -DENABLE_GAPI_TESTS=OFF \
    -DENABLE_BEH_TESTS=OFF \
    -DENABLE_FUNCTIONAL_TESTS=OFF \
    -DENABLE_OV_CORE_UNIT_TESTS=OFF \
    -DENABLE_OV_CORE_BACKEND_UNIT_TESTS=OFF \
    -DENABLE_DEBUG_CAPS=ON \
    -DENABLE_GPU_DEBUG_CAPS=ON \
    -DENABLE_CPU_DEBUG_CAPS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    .. && \
  make -j 8 && \
  make install

ARG CUSTOM_IE_DIR=${CUSTOM_OV_INSTALL_DIR}/runtime
ARG CUSTOM_IE_LIBDIR=${CUSTOM_IE_DIR}/lib/intel64
ENV CUSTOM_OV=${CUSTOM_IE_DIR}

ENV OpenVINO_DIR=${CUSTOM_IE_DIR}/cmake
ENV InferenceEngine_DIR=${CUSTOM_IE_DIR}/cmake
ENV TBB_DIR=${CUSTOM_IE_DIR}/3rdparty/tbb/cmake
ENV ngraph_DIR=${CUSTOM_IE_DIR}/cmake
ENV LD_LIBRARY_PATH=${CUSTOM_IE_DIR}/3rdparty/tbb/lib:${CUSTOM_IE_LIBDIR}:$LD_LIBRARY_PATH

WORKDIR ${WORKSPACE}
CMD ["/bin/bash"]
