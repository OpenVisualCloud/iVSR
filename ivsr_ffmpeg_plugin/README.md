# iVSR FFmpeg plugin
In this folder, two FFmpeg plugins are provided to run the inference of `Enhanced BasicVSR`/`Enhanced EDSR`/`SVP` 
given an input video 
on Intel CPU and Intel GPUs.

| Subfolder                 | Description                               | How to use                                                                                                                               |
|---------------------------|-------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| based_on_ivsr_sdk_backend | FFmpeg plugin that calls iVSR SDK API.    | Check [this](./based_on_ivsr_sdk_backend/README.md) for more details.  |
| based_on_ov_backend       | FFmpeg plugin that calls OpenVINO 2022.1. | Check [this](./based_on_ov_backend/README.md) for more details.        |
