#!/bin/bash
OV_VERSION="2022.3"
# Parse the --ov_version
while [ $# -gt 0 ]; do
    case "$1" in
        --ov_version)
            shift
            if [ "$1" = "2022.3" ] || [ "$1" = "2023.2" ]; then
                OV_VERSION=$1
            else
                echo "Usage: $0  --ov_version [2022.3|2023.2]"
                exit 1
            fi
            shift
            ;;
        *)
            echo "Usage: $0  --ov_version [2022.3|2023.2]"
            exit 1
            ;;
    esac
done
IVSR_OV_DIR=${IVSR_DIR}/ivsr_ov/based_on_openvino_${OV_VERSION}/openvino
export PROJECTDIR=${PWD}
export WORKSPACE=${PWD}/workspace
export LD_LIBRARY_PATH=${WORKSPACE}/opencv-4.5.3-openvino-2021.4.2/install/lib:$LD_LIBRARY_PATH
export OpenCV_DIR=${WORKSPACE}/opencv-4.5.3-openvino-2021.4.2/install/lib/cmake/opencv4
export IVSR_DIR=${WORKSPACE}/ivsr
export IVSR_OV_DIR=${IVSR_DIR}/ivsr_ov/based_on_openvino_${OV_VERSION}/openvino
export CUSTOM_OV_INSTALL_DIR=${IVSR_OV_DIR}/install
export IVSR_SDK_DIR=${IVSR_DIR}/ivsr_sdk/
export LD_LIBRARY_PATH=${IVSR_SDK_DIR}/lib:$LD_LIBRARY_PATH
export CUSTOM_IE_DIR=${CUSTOM_OV_INSTALL_DIR}/runtime
export CUSTOM_IE_LIBDIR=${CUSTOM_IE_DIR}/lib/intel64
export CUSTOM_OV=${CUSTOM_IE_DIR}
export OpenVINO_DIR=${CUSTOM_IE_DIR}/cmake
export InferenceEngine_DIR=${CUSTOM_IE_DIR}/cmake
export TBB_DIR=${CUSTOM_IE_DIR}/3rdparty/tbb/cmake
export ngraph_DIR=${CUSTOM_IE_DIR}/cmake
export LD_LIBRARY_PATH=${CUSTOM_IE_DIR}/3rdparty/tbb/lib:/usr/local/lib:${CUSTOM_IE_LIBDIR}:$LD_LIBRARY_PATH
bash ${CUSTOM_OV_INSTALL_DIR}/setupvars.sh
sudo ldconfig