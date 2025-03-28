# iVSR Release Notes

# Release v25.03

## New and Changes in v25.03
- Update iVSR plugion to FFmpeg n7.1. Note the options setting of "dnn_processing" filter is updated.
- Enabled OpenVINO 2024.5 in the dockerfiles.
- Added support of Rocky linux 9.3.
- Enabled support of 10bit video in the iVSR FFmpeg plugin and SDK; SVP models updated to support 10bit video.
- Enabled async processing mode in iVSR SDK and its plugin.
- iVSR API performance improved by 3-4.5x (SVP-Basic model as inference workload), resulting in faster inference pipeline.
- New SVP Y models introduced with performance improvement (1.58x for SVP-Basic, 8x for SVP-SE, on 1 Flex170 card).

## Bug Fixes
- Provided robust input resolution checking, and input options checking.
- Fixed segment fault issue in vsr_sample if the reshape_values have odd number.
- Fixed one random crash issue in infer_completion_callback() API.

## Known Limitations/Issues
- If the model-guard protected model is loaded, it prints the following *error* messages. They can be ignored as its normal procedure for this kind of model files.<br>
[libprotobuf ERROR thirdparty/protobuf/protobuf/src/google/protobuf/text_format.cc:335] Error parsing text-format tensorflow.GraphDef: 1:2: Message type "tensorflow.GraphDef" has no field named "T".<br>
[libprotobuf ERROR thirdparty/protobuf/protobuf/src/google/protobuf/text_format.cc:335] Error parsing text-format tensorflow.GraphDef: 1:2: Message type "tensorflow.GraphDef" has no field named "T".
- For Enhanced EDSR, or SVP models, some resolutions like 240x426/144x256/234x426/238x246/220x400 don't work with OpenVINO 2023.2. You can switch to OpenVINO 2024.5.
- GPU driver is not installed in the docker files for Rocky Linux 9.
- There is color shift for some green/yellow colors after processing with Enhanced EDSR model.
- Specifying "-vframes <n>" in the ffmpeg command line to let pipeline exit before EOS, may cause core dump. You may remove this option, or specifying "nireq=1" option to dnn_processing filter to avoid it.

# Release v24.05

## New and Changes in v24.05
- Updated iVSR plugin to FFmpeg n6.1.
- Enabled the ability to change model input shapes in the SDK.
- Enabled Y-frame input support.
- Updated Enhanced BasicVSR and Enhanced EDSR models to support reshape.
- Updated SVP-Basic and SVP-SE models with improved inference performance.
- Preview version of TSENet model support.
- Removed the "input_size" parameter from the ivsr_process() API.
- Added one build option to disable applying OpenVINO patches which are required to support Enhanced BasicVSR model.

## Bug Fixes
- Fixed the issue of improper calling of ivsr_process() for the first frame in the FFmpeg plugin.
- Refined the SDK initialization process in the FFmpeg plugin, and removed several misleading warnings.

## Known Limitations
- iVSR SDK is runing in sync mode only. Aync mode is not enabled yet.
- The patch-based solution feature is not enabled in the FFmpeg plugin yet. It can be enabled by setting vsr_sample's "reshape_values" option.
- Parallel inference on heterogeneous hardware is not enabled yet.
- Only 8-bit data is supported in vsr_sample or iVSR FFmpeg plugin.
- Enhanced BasicVSR model works only on OpenVINO 2022.3 with the patches applied.
- The Enhanced BasicVSR model supports only input sizes with widths that are divisible by 32.
