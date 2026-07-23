# iVSR FFmpeg plugin - iVSR SDK based
The folder `ivsr_ffmpeg_plugin` enables model inference using FFmpeg with iVSR SDK as backend. It provides additional `ivsr` backend for the DNN interface called by the `dnn_processing` filter.<br>
The patches included in `patches` folder are specifically for FFmpeg n8.1.<br>

<div align=center>
<img src="./figs/ffmpeg_ivsr_sdk_backend.png" width = 80% height = 80% />
</div>

## Docker image build and test

For full instructions on building the Docker image, see [docs/docker_image_build.md](../docs/docker_image_build.md).

## How to run inference with FFmpeg-plugin
To run inference with iVSR SDK, you need to specify `ivsr` as the backend for the `dnn_processing` filter. Here is an example of how to do it: `dnn_processing=dnn_backend=ivsr`. <br>
Additionally, there are other parameters that you can use. These parameters are listed in the table below:<br>

> **Model dispatch (patches 0005-0007):** Two dispatch paths are supported for backward compatibility:
> 
> 1. **Legacy integer path** (`model_type=0..8`): Use integer values to select built-in model descriptors. Production code using `model_type=1..8` continues to work unchanged.
> 2. **JSON config path** (`model_config=<path>.json`): Use JSON descriptor files for runtime configuration. Provides flexibility for model customization without code changes.
> 
> **Priority**: When both are set, `model_config` takes priority over `model_type`. This enables custom JSON configs to override built-in descriptors.
> 
> Canonical JSON config files are provided in `ivsr_ffmpeg_plugin/model_configs/`. Both paths produce identical output for the same model.

> **OpenVINO version:** Enhanced BasicVSR requires OpenVINO **2022.3** with custom patches. All other models (SVP, EDSR, CustVSR, TSENet, RIFE, SPAN, VideoSeal, HDRTVNet-LE) require OpenVINO **2026.1** (installed via apt). The `build.sh` script in the project root defaults to OV 2026.1.

|AVOption name|Description|Default value|Recommended value(s)|
|:--|:--|:--|:--|
|dnn_backend|DNN backend framework name|native|ivsr|
|model|path to model file|NULL|Available full path of the released model files|
|input|input name of the model|NULL|input|
|output|output name of the model|NULL|output|
|device|device for inference task|CPU|CPU or GPU|
|model_type|Built-in model selector using integer values: `0`=BasicVSR, `1`=VideoProc, `2`=EDSR, `3`=CustVSR, `4`=TSENet, `5`=RIFE, `6`=SPAN, `7`=VideoSeal, `8`=HDRTVNet-LE. **Legacy option**: For backward compatibility with existing production code. New projects should use `model_config` instead.|0|0-8 (see table below)|
|model_config|Path to a JSON model descriptor file. Takes priority over `model_type` when both are set. Enables runtime model customization without code changes. Canonical configs: `model_configs/{videoproc,edsr,custvsr,tsenet,rife,span,videoseal,hdrtvnet_le}_config.json`. See `ivsr_model_config.template.json` for all fields.|NULL|Full path to the appropriate `*_config.json`|
|normalize_factor|Legacy normalizing factor for models that do not require input normalization to [0, 1]. For JSON-config models this is handled inside the config.|1.0|255.0 for Enhanced EDSR (legacy), 1.0 for all other models|
|num_streams|number of execution streams for throughput mode (valid only for GPU devices)|1|use `benchmark_app` to determine the best value|
|extension|extension lib file full path, required for Enhanced BasicVSR|—|—|
|op_xml|custom op xml file full path, required for Enhanced BasicVSR|—|—|
|nif|number of input frames in batch sent to the DNN backend|1|3 for Enhanced BasicVSR; for JSON-config models this is set inside the config|
|nireq|number of infer requests|0|leave as default or set to match CPU core count|

### Model Type Integer Mapping

| `model_type` | Model Name | Equivalent JSON Config | Input Format | Notes |
|:-------------|:-----------|:-----------------------|:-------------|:------|
| 0 | Enhanced BasicVSR | N/A (built-in only) | rgb24 | Requires OV 2022.3 + patches |
| 1 | VideoProc (SVP) | `videoproc_config.json` | yuv420p or rgb24 | Y-channel SR, auto-detects color |
| 2 | Enhanced EDSR | `edsr_config.json` | rgb24 | Single-frame RGB SR |
| 3 | Custom VSR | `custvsr_config.json` | yuv420p | Y-channel only |
| 4 | TSENet | `tsenet_config.json` | rgb24 | 3-frame temporal SR |
| 5 | RIFE | `rife_config.json` | rgb24 | Frame interpolation |
| 6 | SPAN | `span_config.json` | rgb24 | Single-frame RGB SR |
| 7 | VideoSeal | `videoseal_config.json` | rgb24 | Invisible watermarking |
| 8 | HDRTVNet-LE | `hdrtvnet_le_config.json` | rgb24 | HDR local enhancement |

Here are examples of FFmpeg command lines to run inference with the supported models using the `ivsr` backend. Both **legacy integer** (`model_type`) and **JSON config** (`model_config`) approaches are shown for comparison.<br>

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

> **All models below support both dispatch paths (patches 0005-0007).** You can use either:
> - **Legacy**: `model_type=N` (where N is 1-8) for built-in descriptors
> - **JSON**: `model_config=<path>.json` for custom configurations
> 
> Both produce identical output. Canonical JSON configs are in `ivsr_ffmpeg_plugin/model_configs/`.

### SVP / VideoProc (`model_type=1`)
Input pixel format: `rgb24` (RGB model variant) or `yuv420p` (Y-channel model variant). Raw pixel values `[0, 255]` are passed to the model as float32 without normalisation. `color_format_auto: 1` enables automatic I420/RGB colour-format selection based on the input pixel format.

**Legacy integer path** (`model_type=1`):
```bash
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
# Y-channel variant
./ffmpeg -i <your test video> \
  -vf format=yuv420p,dnn_processing=dnn_backend=ivsr:model=<svp_model.xml>:input=input:output=output:model_type=1:device=<CPU or GPU> \
  -pix_fmt yuv420p test_out.mp4
```

**JSON config path** (equivalent):
```bash
# Y-channel variant
./ffmpeg -i <your test video> \
  -vf format=yuv420p,dnn_processing=dnn_backend=ivsr:model=<svp_model.xml>:input=input:output=output:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/videoproc_config.json:device=<CPU or GPU> \
  -pix_fmt yuv420p test_out.mp4
```

### Enhanced EDSR (`model_type=2`)
Input pixel format: `rgb24`. Single-frame RGB super-resolution. Output precision is fixed at `fp32`. Both FP32 and INT8 model variants are supported.

**Legacy integer path** (`model_type=2`):
```bash
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<edsr_model.xml>:input=input:output=output:model_type=2:device=<CPU or GPU> \
  -pix_fmt yuv420p test_out.mp4
```

**JSON config path** (equivalent):
```bash
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<edsr_model.xml>:input=input:output=output:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/edsr_config.json:device=<CPU or GPU> \
  -pix_fmt yuv420p test_out.mp4
```

### Custom VSR (`model_type=3`)
Input pixel format: `yuv420p` (Y-channel only). Single-frame inference on the luma plane.

**Legacy integer path** (`model_type=3`):
```bash
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> \
  -vf format=yuv420p,dnn_processing=dnn_backend=ivsr:model=<custvsr_model.xml>:input=input:output=output:model_type=3:device=<CPU or GPU> \
  -pix_fmt yuv420p test_out.mp4
```

**JSON config path** (equivalent):
```bash
./ffmpeg -i <your test video> \
  -vf format=yuv420p,dnn_processing=dnn_backend=ivsr:model=<custvsr_model.xml>:input=input:output=output:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/custvsr_config.json:device=<CPU or GPU> \
  -pix_fmt yuv420p test_out.mp4
```

### TSENet (`model_type=4`)
Input pixel format: `rgb24`. Uses a 3-frame sliding window with first-frame duplication priming. Input is passed as raw `[0, 255]` float32; output is rescaled from `[0, 1]` to `[0, 255]`.

**Legacy integer path** (`model_type=4`):
```bash
cd <iVSR project path>/ivsr_ffmpeg_plugin/ffmpeg
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<tsenet_model.xml>:input=input:output=output:model_type=4:device=<CPU or GPU> \
  -pix_fmt yuv420p test_out.mp4
```

**JSON config path** (equivalent):
```bash
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<tsenet_model.xml>:input=input:output=output:model_config=<iVSR project path>/ivsr_ffmpeg_plugin/model_configs/tsenet_config.json:device=<CPU or GPU> \
  -pix_fmt yuv420p test_out.mp4
```

### Additional Models

The following models support both dispatch paths. For brevity, only the **legacy integer path** is shown. To use JSON config, replace `model_type=N` with `model_config=<path>/model_configs/<model>_config.json`.

#### RIFE - Frame Interpolation (`model_type=5`)
```bash
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<rife_model.xml>:input=input:output=output:model_type=5:device=<CPU or GPU> \
  test_out.mp4
```

#### SPAN - Single-Frame SR (`model_type=6`)
```bash
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<span_model.xml>:input=input:output=output:model_type=6:device=<CPU or GPU> \
  -pix_fmt yuv420p test_out.mp4
```

#### VideoSeal - Invisible Watermarking (`model_type=7`)
```bash
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<videoseal_model.xml>:input=input:output=output:model_type=7:device=<CPU or GPU> \
  test_out.mp4
```

#### HDRTVNet-LE - HDR Local Enhancement (`model_type=8`)
```bash
./ffmpeg -i <your test video> \
  -vf format=rgb24,dnn_processing=dnn_backend=ivsr:model=<hdrtvnet_le_model.xml>:input=input:output=output:model_type=8:device=<CPU or GPU> \
  test_out.mp4
```

---

## Migration Guide

### For Existing Production Code
If your code currently uses `model_type=1..8`, **no changes are required**. Patch 0007 restores full backward compatibility.

### For New Projects
We recommend using JSON config files for better flexibility:
```bash
# Instead of: model_type=2
# Use: model_config=/path/to/model_configs/edsr_config.json
```

### Custom Model Variants
JSON configs enable runtime customization without code changes. Copy a canonical config and modify as needed:
```bash
cp model_configs/edsr_config.json custom_edsr.json
# Edit custom_edsr.json to change align, normalize_input, etc.
./ffmpeg ... model_config=custom_edsr.json ...
```

---

## Troubleshooting

### "model_type out of range" Error
- **Cause**: Patch 0007 not applied
- **Fix**: Rebuild with `./build.sh --ov_version 2026.1` (applies all patches including 0007)

### Different Output Between model_type and model_config
- **Expected**: Both should produce identical output for the same model
- **Debug**: Check that `model_table[N]` matches the canonical JSON config
- **Verify**: `md5sum` the output files from both paths

---

## See Also

- **Patch Documentation**: `PATCH_0007_README.md` - Details on backward compatibility
- **Build Guide**: `PATCH_APPLIED.md` - Build and verification instructions
- **Model Configs**: `model_configs/*.json` - Canonical configuration files
- **Template**: `ivsr_model_config.template.json` - All available config fields
