# iVSR FFmpeg plugin - iVSR SDK based
The folder `ivsr_ffmpeg_plugin` enables model inference using FFmpeg with iVSR SDK as backend. It provides additional `ivsr` backend for the DNN interface called by the `dnn_processing` filter.<br>
The patches included in `patches` folder are specifically for FFmpeg n7.1.<br>

<div align=center>
<img src="./figs/ffmpeg_ivsr_sdk_backend.png" width = 80% height = 80% />
</div>

## How to run inference with FFmpeg-plugin
To run inference with iVSR SDK, you need to specify `ivsr` as the backend for the `dnn_processing` filter. Here is an example of how to do it: `dnn_processing=dnn_backend=ivsr`. <br>
Additionally, there are other parameters that you can use. These parameters are listed in the table below:<br>

> **Model dispatch (patch 0005):** Enhanced BasicVSR is the only built-in model (`model_type=0`). All other models — SVP/VideoProc, Enhanced EDSR, Custom VSR, TSENet, RIFE, and VideoSeal — are configured at runtime via a JSON descriptor file passed with `model_config`. When `model_config` is set, `model_type` is ignored. Canonical config files are provided in `ivsr_ffmpeg_plugin/model_configs/`.

|AVOption name|Description|Default value|Recommended value(s)|
|:--|:--|:--|:--|
|dnn_backend|DNN backend framework name|native|ivsr|
|model|path to model file|NULL|Available full path of the released model files|
|input|input name of the model|NULL|input|
|output|output name of the model|NULL|output|
|device|device for inference task|CPU|CPU or GPU|
|model_type|Built-in model selector. `0` = Enhanced BasicVSR (only remaining built-in). For all other models, omit `model_type` and set `model_config` instead.|0|0 (BasicVSR only)|
|model_config|Path to a JSON model descriptor file. When set, `model_type` is ignored and all dispatch uses the JSON config. Canonical configs: `model_configs/{videoproc,edsr,custvsr,tsenet,rife,videoseal}_config.json`. See `ivsr_model_config.template.json` for all fields.|NULL|Full path to the appropriate `*_config.json`|
|normalize_factor|Legacy normalizing factor for models that do not require input normalization to [0, 1]. For JSON-config models this is handled inside the config.|1.0|255.0 for Enhanced EDSR (legacy), 1.0 for all other models|
|num_streams|number of execution streams for throughput mode (valid only for GPU devices)|1|use `benchmark_app` to determine the best value|
|extension|extension lib file full path, required for Enhanced BasicVSR|—|—|
|op_xml|custom op xml file full path, required for Enhanced BasicVSR|—|—|
|nif|number of input frames in batch sent to the DNN backend|1|3 for Enhanced BasicVSR; for JSON-config models this is set inside the config|
|nireq|number of infer requests|0|leave as default or set to match CPU core count|

Here are examples of FFmpeg command lines to run inference with the supported models using the `ivsr` backend.<br>

### Enhanced BasicVSR (built-in, `model_type=0`)
Input pixel format: `rgb24`. Requires OpenVINO 2022.3 with patches applied.
```
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<basic_vsr_model.xml>:input=input:output=output:nif=3:device=<CPU or GPU>:model_type=0:extension=<iVSR project path>/ivsr_ov/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so:op_xml=<iVSR project path>/ivsr_ov/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml \
  test_out.mp4
```
The `extension` and `op_xml` options are required for Enhanced BasicVSR. After applying OpenVINO's patches and building OpenVINO, the extension lib is at `<OpenVINO folder>/openvino/bin/intel64/Release/libcustom_extension.so` and the op xml is at `<OpenVINO folder>/openvino/flow_warp_cl_kernel/flow_warp.xml`.<br>

---

> **All models below use the JSON config dispatch path (patch 0005).** Pass the path to the appropriate config file via `model_config`. Canonical configs are in `ivsr_ffmpeg_plugin/model_configs/`.

### SVP / VideoProc
Input pixel format: `rgb24` (RGB model variant) or `yuv420p` (Y-channel model variant). Config file: `model_configs/videoproc_config.json`.
```
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
# RGB variant
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<svp_model.xml>:input=input:output=output:device=<CPU or GPU>:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/videoproc_config.json \
  -pix_fmt yuv420p test_out.mp4
# Y-channel variant
./ffmpeg -i <your test video> \
  -vf format=yuv420p,dnn_processing=dnn_backend=ivsr:model=<svp_model.xml>:input=input:output=output:device=<CPU or GPU>:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/videoproc_config.json \
  -pix_fmt yuv420p test_out.mp4
```

### Enhanced EDSR
Input pixel format: `rgb24`. Config file: `model_configs/edsr_config.json` (output precision is derived from bit depth automatically).
```
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<edsr_model.xml>:input=input:output=output:device=<CPU or GPU>:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/edsr_config.json \
  -pix_fmt yuv420p test_out.mp4
```

### Custom VSR
Input pixel format: `yuv420p`. Input shape: `[1, (Y channel)1, H, W]`, output shape: `[1, 1, 2xH, 2xW]`. Config file: `model_configs/custvsr_config.json`.
```
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> \
  -vf format=yuv420p,dnn_processing=dnn_backend=ivsr:model=<customvsr_model.xml>:input=input:output=output:nireq=1:device=CPU:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/custvsr_config.json \
  -pix_fmt yuv420p test_out.mp4
```

### TSENet
Input pixel format: `rgb24`. Uses a 3-frame sliding window (`nif=3`) with first-frame duplication priming. Config file: `model_configs/tsenet_config.json`.
```
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<tsenet_model.xml>:input=input:output=output:device=<CPU or GPU>:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/tsenet_config.json \
  -pix_fmt yuv420p test_out.mp4
```

### RIFE (Frame Interpolation)
Input pixel format: `rgb24`. Uses a 2-frame sliding window (`nif=2`). Input is normalised to `[0, 1]` (float32); output is scaled back to `[0, 255]`. Config file: `model_configs/rife_config.json`.
```
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<rife_model.xml>:input=input:output=output:device=<CPU or GPU>:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/rife_config.json \
  test_out.mp4
```

### VideoSeal (Invisible Watermarking)
Input pixel format: `rgb24`. Single-frame inference; embeds an invisible watermark into each frame. Input is packed as raw `[0, 255]` float32 (no `/255` normalisation). Config file: `model_configs/videoseal_config.json`.
```
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<videoseal_model.xml>:input=input:output=output:device=<CPU or GPU>:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/videoseal_config.json \
  test_out.mp4
```
