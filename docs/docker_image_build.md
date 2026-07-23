# Docker image build guide

### 1. Set timezone correctly before building docker image.
The following command takes Shanghai as an example.

  ```bash
  timedatectl set-timezone Asia/Shanghai
  ```

### 2. Set up docker service

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
printf "[Service]\nEnvironment=\"HTTPS_PROXY=$https_proxy\" \"NO_PROXY=$no_proxy\"\n" | sudo tee  /etc/systemd/system/docker.service.d/proxy.conf
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 3. Build docker image

```bash
cd ./ivsr_ffmpeg_plugin
./build_docker.sh --enable_ov_patch [true|false] --ov_version [2022.3|2023.2|2024.5|2024.5s|2026.1] --os_version [rockylinux9|ubuntu22]
```

- `enable_ov_patch`: Set to `true` or `false` to enable or disable OpenVINO 2022.3 patches, which are needed to support the Enhanced BasicVSR model. Ignored for all versions other than `2022.3`.
- `ov_version`: OpenVINO version to install. `2022.3`, `2023.2`, and `2024.5` are built from source; `2024.5s` and `2026.1` install via apt. The patches to enable the Enhanced BasicVSR model are only available for `2022.3`.
- `os_version`: Base OS — `ubuntu22` (Ubuntu 22.04) or `rockylinux9` (Rocky Linux 9.3).

If the docker image builds successfully, you can see a docker image named `ffmpeg_ivsr_sdk_${os_version}_ov${ov_version}` in the output of `docker image ls`:

```bash
docker image ls | grep ffmpeg_ivsr_sdk
```

For example:

```
ffmpeg_ivsr_sdk_ubuntu22_ov2026.1    latest   ...
ffmpeg_ivsr_sdk_ubuntu22_ov2024.5s   latest   ...
ffmpeg_ivsr_sdk_rockylinux9_ov2022.3 latest   ...
```

### 4. Sanity-check the image (no model required)

Verify the `ivsr` backend is registered in the built FFmpeg:

```bash
docker run --rm ffmpeg_ivsr_sdk_<os_version>_ov<ov_version>:latest \
    ffmpeg -filters 2>&1 | grep ivsr
```

Verify the installed OpenVINO version:

```bash
docker run --rm ffmpeg_ivsr_sdk_<os_version>_ov<ov_version>:latest \
    python3 -c "import openvino; print(openvino.__version__)"
```

### 5. Start Docker Container

```bash
# The backslash at the end of the line indicates that the command continues on the next line
sudo docker run -itd --name ffmpeg_ivsr_sdk_container --privileged \
  -e MALLOC_CONF="oversize_threshold:1,background_thread:true,metadata_thp:auto,dirty_decay_ms:9000000000,muzzy_decay_ms:9000000000" \
  -e http_proxy=$http_proxy \
  -e https_proxy=$https_proxy \
  -e no_proxy=$no_proxy \
  --shm-size=128g \
  --device=/dev/dri:/dev/dri \
  ffmpeg_ivsr_sdk_<os_version>_ov<ov_version>:latest bash

# Open another shell terminal to interact with the running container
sudo docker exec -it ffmpeg_ivsr_sdk_container bash
```

`--device=/dev/dri:/dev/dri` passes the host GPU through to the container for GPU inference (`device=GPU`).
Mount your model directory and a test video, then run the desired model. The examples below use `docker run --rm` for a one-shot test; replace the image tag, model path, and video path as needed.

**Enhanced EDSR (2× upscale, `rgb24` input, `model_type=2`):**

```bash
docker run --rm \
  -v /path/to/models:/models:ro \
  -v /path/to/input.mp4:/input.mp4:ro \
  -v /path/to/output:/output \
  ffmpeg_ivsr_sdk_<os_version>_ov<ov_version>:latest \
  ffmpeg -hide_banner -y -i /input.mp4 \
    -vf 'format=rgb24,dnn_processing=dnn_backend=ivsr:model=/models/<edsr_model.xml>:input=input:output=output:nif=1:device=CPU:model_type=2:normalize_factor=255.0' \
    -pix_fmt yuv420p /output/edsr_out.mp4
```

Expected: output resolution is 2× the input (e.g. 1280×720 → 2560×1440).

**SVP-Basic Y-channel (pre-filter / bitrate reduction, `yuv420p` input, `model_type=1`):**

```bash
docker run --rm \
  -v /path/to/models:/models:ro \
  -v /path/to/input.mp4:/input.mp4:ro \
  -v /path/to/output:/output \
  ffmpeg_ivsr_sdk_<os_version>_ov<ov_version>:latest \
  ffmpeg -hide_banner -y -i /input.mp4 \
    -vf 'format=yuv420p,dnn_processing=dnn_backend=ivsr:model=/models/<svp_model.xml>:input=input:output=output:nif=1:device=CPU:model_type=1' \
    -pix_fmt yuv420p /output/svp_out.mp4
```

Expected: output resolution matches input; bitrate is reduced compared to re-encoding without SVP.

For additional FFmpeg filter options and command-line examples for all supported models, see the [FFmpeg plugin README](../ivsr_ffmpeg_plugin/README.md).
