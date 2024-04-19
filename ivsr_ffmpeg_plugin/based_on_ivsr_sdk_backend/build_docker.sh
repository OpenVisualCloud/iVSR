#!/bin/sh
# Default value for the ENABLE_GPU_PATCH flag
ENABLE_GPU_PATCH="true"

# Parse the --enable_gpu_patch flag
while [ $# -gt 0 ]; do
    case "$1" in
        --enable_gpu_patch)
			shift
			value=$(echo $1 | tr '[:upper:]' '[:lower:]')
            if [ "$value" == "false" ]; then
				ENABLE_GPU_PATCH=$value
			fi
            shift
            ;;
        *)
            echo "Usage: $0 --enable_gpu_patch [true|false]"
            exit 1
            ;;
    esac
done

docker build --build-arg http_proxy=$http_proxy \
 	--build-arg https_proxy=$https_proxy \
	--build-arg no_proxy=$no_proxy \
	--build-arg PYTHON=python3.10 \
	--build-arg ENABLE_GPU_PATCH=$ENABLE_GPU_PATCH \
	-f Dockerfile -t ffmpeg_ivsr_sdk \
	../../
