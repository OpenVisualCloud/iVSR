#!/bin/bash

# Copyright 2025 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -e

base_dir=$(pwd)
ov_version=2026.1

# Function to display usage information
usage() {
    echo "Usage: $0  --ov_version [2022.3|2024.5|2026.1]"
    exit 1
}

prepare_dependencies() {
  echo "Preparing dependencies..."
  sudo apt-get install -y --no-install-recommends \
    curl ca-certificates gpg-agent software-properties-common

  sudo apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    apt-utils cmake cython3 flex bison gcc g++ git make patch pkg-config wget \
    libdrm-dev libtool libusb-1.0-0-dev xz-utils ocl-icd-opencl-dev opencl-headers \
    apt-utils gpg-agent software-properties-common wget python3-dev libpython3-dev python3-pip nasm yasm
}

config_git_users() {
  if [ -z "$(git config --global user.name)" ]; then
      git config --global user.name "no name"
  fi

  if [ -z "$(git config --global user.email)" ]; then
      git config --global user.email "noname@example.com"
  fi
}

install_openvino_from_source() {
  echo "Start building OpenVINO"

  ov_repo=https://github.com/openvinotoolkit/openvino.git
  ov_branch=${ov_version}.0
  ivsr_ov_dir=${base_dir}/ivsr_ov/based_on_openvino_${ov_version}/openvino
  if [ ! -d "${ivsr_ov_dir}" ]; then
    git clone --depth 1 --branch ${ov_branch} ${ov_repo} ${ivsr_ov_dir}
    git config --global --add safe.directory ${ivsr_ov_dir}
  fi
  cd ${ivsr_ov_dir}
  git submodule update --init --recursive

  ## applying ov22.3 patches to enable Enhanced BasicVSR model
  if git tag --points-at HEAD 2>/dev/null | grep -q "^${ov_branch}$"; then
    for patch_file in $(find ../patches -iname "*.patch" | sort -n);do
        echo "Applying: ${patch_file}"
        git am --whitespace=fix ${patch_file}
    done
  else
    echo "OpenVINO patches already applied, skipping..."
  fi

  mkdir -p build && cd build && \
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
  make -j $(nproc --all) && \
  make install
  echo "Build OpenVINO finished."
    
  source ${PWD}/../install/setupvars.sh
}

build_install_ivsr_sdk() {
  echo "Building and installing iVSR SDK..."

  ivsr_sdk_dir=${base_dir}/ivsr_sdk/
  cd ${ivsr_sdk_dir}
  sudo rm -rf build
  mkdir -p build && cd build && cmake \
    -DENABLE_LOG=OFF -DENABLE_PERF=OFF -DENABLE_THREADPROCESS=ON \
    -DENABLE_IRGUARD=${enable_irguard} \
    -DCMAKE_BUILD_TYPE=Release .. && \
  make -j $(nproc --all)
  sudo make install
  echo "Build ivsr sdk finished."
}

build_install_svt_av1() {
    echo "Building and installing SVT-AV1 library..."
    svtav1_repo=https://gitlab.com/AOMediaCodec/SVT-AV1.git
    svtav1_branch=v4.2.0
    ivsr_svtav1_dir=${base_dir}/ivsr_svtav1/SVT-AV1
    if [ ! -d "${ivsr_svtav1_dir}" ]; then
        git clone --depth 1 --branch ${svtav1_branch} ${svtav1_repo} ${ivsr_svtav1_dir}
        git config --global --add safe.directory ${ivsr_svtav1_dir}
    fi
    cd ${ivsr_svtav1_dir}/Build
    cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
    make -j$(nproc)
    sudo make install
    echo "Build svt-av1 finished."
}

build_ffmpeg() {
  echo "Building FFMPEG with specific libraries support..."
  sudo -E apt-get update && \
    DEBIAN_FRONTEND=noninteractive sudo apt-get install -y --no-install-recommends \
    ca-certificates tar g++ wget pkg-config libglib2.0-dev flex bison gobject-introspection libgirepository1.0-dev \
    python3-dev libx11-dev libxv-dev libxt-dev libasound2-dev libpango1.0-dev libtheora-dev libvisual-0.4-dev libgl1-mesa-dev \
    libcurl4-gnutls-dev librtmp-dev libx264-dev libx265-dev libde265-dev libva-dev libtbb-dev \
    patchutils

  ffmpeg_dir=$base_dir/ivsr_ffmpeg_plugin/ffmpeg
  ffmpeg_tag=n8.1
  ffmpeg_repo=https://github.com/FFmpeg/FFmpeg.git

  git config --global --add safe.directory ${ffmpeg_dir}

  if [ ! -d "${ffmpeg_dir}/.git" ]; then
    git clone --depth 1 --branch ${ffmpeg_tag} ${ffmpeg_repo} ${ffmpeg_dir}
  fi

  # Fix ownership of root-owned files from previous sudo builds
  sudo chown -R $(id -u):$(id -g) "${ffmpeg_dir}"

  cd ${ffmpeg_dir}
  git am --abort 2>/dev/null || true
  # Ensure the target tag is locally reachable (handles a prior clone at a different tag)
  if ! git rev-parse "${ffmpeg_tag}" >/dev/null 2>&1; then
    git fetch --depth 1 origin "refs/tags/${ffmpeg_tag}:refs/tags/${ffmpeg_tag}"
  fi
  git checkout -f "${ffmpeg_tag}"
  # Remove untracked files left by previous patch applications so git apply
  # can create new files (e.g. dnn_backend_ivsr.c) without conflicts.
  git clean -fd -- libavfilter libswscale

  # ---------------------------------------------------------------
  # Apply all iVSR patches for n8.1.
  # Patch 0001: strip configure, dnn_interface.c, and swscale_unscaled.c
  #   hunks — those three files are fully covered by patch 0004.
  # Patch 0004: n8.1-native patch for configure, dnn_interface.c and
  #   swscale_unscaled.c (exact n8.1 context; no sed required).
  # Patches 0002/0003: fix-ups for dnn_backend_ivsr.c (added by 0001).
  # ---------------------------------------------------------------
  rm -f *.patch
  cp "$base_dir/ivsr_ffmpeg_plugin/patches/"*.patch .

  filterdiff \
    -x '*/configure' \
    -x '*/dnn_interface.c' \
    -x '*/swscale_unscaled.c' \
    0001-*.patch | \
    git apply --3way --ignore-whitespace -

  git apply --ignore-whitespace 0004-*.patch

  # Stage new files added by 0001 so 3-way merge can resolve them
  git add -A

  git apply --3way --whitespace=fix 0002-*.patch
  git apply --3way --whitespace=fix 0003-*.patch
  git apply --3way --whitespace=fix 0005-*.patch
  git apply --3way --whitespace=fix 0006-*.patch
  git apply --3way --whitespace=fix 0007-*.patch

  ./configure \
      --enable-gpl \
      --enable-nonfree \
      --disable-static \
      --disable-doc \
      --enable-shared \
      --enable-version3 \
      --enable-libivsr \
      --enable-libx264 \
      --enable-libx265 \
      --enable-libsvtav1

  make -j$(nproc)
  sudo make install
  sudo ldconfig
}

install_openvino_from_apt() {
  echo "Installing OpenVINO from apt..."
  local version=$1
  local key_url=https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
  local keyring=/etc/apt/trusted.gpg.d/intel.gpg

  # Download GPG key with timeout; fail loudly if it doesn't work
  if ! wget --timeout=30 --tries=3 -O /tmp/intel-sw-products.pub "${key_url}"; then
    echo "ERROR: Failed to download Intel GPG key from ${key_url}" >&2
    exit 1
  fi
  sudo gpg --yes --output "${keyring}" --dearmor /tmp/intel-sw-products.pub
  rm -f /tmp/intel-sw-products.pub

  if [ ! -s "${keyring}" ]; then
    echo "ERROR: Intel GPG keyring is empty after dearmor step." >&2
    exit 1
  fi

  # Unified repo (all versions from 2024 onwards live here; no year in path)
  # Detect Ubuntu codename suffix expected by the repo (ubuntu22 / ubuntu24)
  local ubuntu_major
  ubuntu_major=$(lsb_release -rs | cut -d. -f1)
  local dist="ubuntu${ubuntu_major}"

  echo "deb https://apt.repos.intel.com/openvino ${dist} main" \
    | sudo tee /etc/apt/sources.list.d/intel-openvino.list

  sudo -E apt-get update && \
    DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y openvino-${version}.0
}

main() {
  while [ "$1" != "" ]; do
    case $1 in
      --ov_version ) shift
                     ov_version=$1
                     ;;
      * ) usage
          exit 1
    esac
    shift
  done

  # irguard model protection is required for OV 2022.3 and 2024.5
  case "${ov_version}" in
    2022.3|2024.5) enable_irguard=ON ;;
    *)             enable_irguard=OFF ;;
  esac

  prepare_dependencies
  config_git_users
  if [ "$ov_version" = "2022.3" ]; then
    install_openvino_from_source
  else
    install_openvino_from_apt "$ov_version" 
  fi
  build_install_ivsr_sdk
  build_install_svt_av1
  build_ffmpeg
}

main "$@"
