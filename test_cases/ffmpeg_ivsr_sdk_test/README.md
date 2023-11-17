# FFmpeg iVSR SDK Plugin Test Cases
## preliminary
* Copy model files to Docker container
```shell
docker cp 0_iVSR_v0.1_models <container id>:/workspace
```
* Enter ffmpeg ivsr sdk plugin directory
```shell
cd /workspace/ivsr/ivsr_ffmpeg_plugin/based_on_ivsr_sdk_backend/ffmpeg
```
* Generate test videos
```shell
./ffmpeg -f lavfi -i testsrc=duration=1:size=1920x1080:rate=30 -c:v libx264 test_video_1080p_fn30.mp4
./ffmpeg -f lavfi -i testsrc=duration=250:size=1920x1080:rate=30 -c:v libx264 test_video_1080p_fn7500.mp4
```

## Function Test Cases
### Case 1: 1080p->4K SR with fp32 1080p model on CPU
```shell
./ffmpeg -i test_video_1080p_fn30.mp4 -vf dnn_processing=dnn_backend=ivsr:model=/workspace/0_iVSR_v0.1_models/ov1_w_custom_fp32/basicvsr_x2_release_ov1_w_custom_fp32_3x1080x1920.xml:input=input:output=output:nif=3:backend_configs='nireq=1&device=CPU' output_fn30_cpu_fp32.mp4
```
### Case 2: 1080p->4K SR with fp32 1080p model on GPU
```shell
./ffmpeg -i test_video_1080p_fn30.mp4 -vf dnn_processing=dnn_backend=ivsr:model=/workspace/0_iVSR_v0.1_models/ov1_w_custom_fp32/basicvsr_x2_release_ov1_w_custom_fp32_3x1080x1920.xml:input=input:output=output:nif=3:backend_configs='nireq=1&device=GPU' output_fn30_gpu_fp32.mp4
```
### Case 3: 1080p->4K SR with int8 1080p model on CPU
```shell
./ffmpeg -i test_video_1080p_fn30.mp4 -vf dnn_processing=dnn_backend=ivsr:model=/workspace/0_iVSR_v0.1_models/ov1_w_custom_int8/basicvsr_x2_release_ov1_w_custom_int8_3x1080x1920.xml:input=input:output=output:nif=3:backend_configs='nireq=1&device=CPU' output_fn30_cpu_int8.mp4
```
### Case 4: 1080p->4K SR with int8 1080p model on GPU
```shell
./ffmpeg -i test_video_1080p_fn30.mp4 -vf dnn_processing=dnn_backend=ivsr:model=/workspace/0_iVSR_v0.1_models/ov1_w_custom_int8/basicvsr_x2_release_ov1_w_custom_int8_3x1080x1920.xml:input=input:output=output:nif=3:backend_configs='nireq=1&device=GPU' output_fn30_gpu_int8.mp4
```
The `function_test.sh` can be used to automatically run above test cases.
```shell
./function_test.sh
```

## Stress Test Cases(Long videos)
### Case 1: 1080p->4K SR with fp32 1080p model on CPU
```shell
./ffmpeg -i test_video_1080p_fn7500.mp4 -vf dnn_processing=dnn_backend=ivsr:model=/workspace/0_iVSR_v0.1_models/ov1_w_custom_fp32/basicvsr_x2_release_ov1_w_custom_fp32_3x1080x1920.xml:input=input:output=output:nif=3:backend_configs='nireq=1&device=CPU' output_fn7500_cpu_fp32.mp4
```
### Case 2: 1080p->4K SR with fp32 1080p model on GPU
```shell
./ffmpeg -i test_video_1080p_fn7500.mp4 -vf dnn_processing=dnn_backend=ivsr:model=/workspace/0_iVSR_v0.1_models/ov1_w_custom_fp32/basicvsr_x2_release_ov1_w_custom_fp32_3x1080x1920.xml:input=input:output=output:nif=3:backend_configs='nireq=1&device=GPU' output_fn7500_gpu_fp32.mp4
```
### Case 3: 1080p->4K SR with int8 1080p model on CPU
```shell
./ffmpeg -i test_video_1080p_fn7500.mp4 -vf dnn_processing=dnn_backend=ivsr:model=/workspace/0_iVSR_v0.1_models/ov1_w_custom_int8/basicvsr_x2_release_ov1_w_custom_int8_3x1080x1920.xml:input=input:output=output:nif=3:backend_configs='nireq=1&device=CPU' output_fn7500_cpu_int8.mp4
```
### Case 4: 1080p->4K SR with int8 1080p model on GPU
```shell
./ffmpeg -i test_video_1080p_fn7500 -vf dnn_processing=dnn_backend=ivsr:model=/workspace/0_iVSR_v0.1_models/ov1_w_custom_int8/basicvsr_x2_release_ov1_w_custom_int8_3x1080x1920.xml:input=input:output=output:nif=3:backend_configs='nireq=1&device=GPU' output_fn7500_gpu_int8.mp4
```
The `stress_test_long.sh` can be used to automatically run above test cases.
```shell
./stress_test_long.sh
```

## Stress Test Cases(Loop)
```shell
./stress_test_loop.sh --loop 100
```