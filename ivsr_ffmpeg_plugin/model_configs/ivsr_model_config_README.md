# iVSR Model Config Files

Each non-BasicVSR model is described by a JSON config file placed in this directory.
At runtime FFmpeg reads the file and configures the iVSR backend without any recompilation.

**FFmpeg usage:**
```
./ffmpeg -i input.mp4 \
  -vf "format=rgb24,dnn_processing=dnn_backend=ivsr:\
model=mymodel.xml:model_config=../model_configs/mymodel_config.json" \
  output.mp4
```

BasicVSR does not use a JSON config — it is a built-in and uses `model_type=0` directly.

---

## Required fields

### `name`
Human-readable label used in FFmpeg log messages.  
**Type:** string  
**Example:** `"RIFE"`, `"VideoSeal"`

### `in_layout`
Memory layout of the input tensor as understood by the iVSR SDK.

| Value | Meaning |
|---|---|
| `"NCHW"` | Batch × Channels × Height × Width (most common for single-frame RGB models) |
| `"NHWC"` | Batch × Height × Width × Channels (VideoProc, CustVSR) |
| `"NFHWC"` | Batch × Frames × Height × Width × Channels (BasicVSR only, built-in) |

---

## Optional fields and their defaults

### `nif`
Number of input frames consumed per inference call.  
**Type:** integer ≥ 1  
**Default (if absent):** `1` (single-frame)  
**When to set:** sliding-window models only — `2` for RIFE, `3` for TSENet.

---

### `channel_divisor`
Divides the channel count reported to FFmpeg so it sees standard 3-channel frames.  
Some models pack multiple frames along the channel axis; this corrects the mismatch.  
**Type:** integer ≥ 1  
**Default (if absent):** `1` (no division)  
**When to set:** `2` for RIFE (two RGB frames → 6 channels ÷ 2), `3` for TSENet (three frames → 9 channels ÷ 3).

---

### `align`
Pads input width and height up to the nearest multiple of this value before reshaping.  
**Type:** integer ≥ 0  
**Default (if absent):** `0` (no alignment)  
**When to set:** `128` for RIFE, `64` for VideoProc.

---

### `in_precision`
Element type of the input tensor sent to the iVSR SDK.  
**Type:** string or absent  
**Supported values:** `"f32"`, `"u8"`, `"u16"`  
**Default (if absent):** inherited from the input frame bit depth (8-bit → `u8`, 10/16-bit → `u16`)  
**When to set:** explicitly `"f32"` for models that always expect float regardless of frame depth (RIFE, SPAN, EDSR, VideoSeal).

---

### `out_layout`
Memory layout of the output tensor.  
**Type:** string  
**Supported values:** `"NCHW"`, `"NHWC"`, `"NFHWC"`  
**Default (if absent):** `"NHWC"` (hard-coded C initializer)  
**⚠️ Must be set explicitly for NCHW output models.** Most models use `"NCHW"` output; only VideoProc and TSENet use `"NHWC"`. Do not omit this field unless the model truly outputs NHWC.

> **TODO:** Change the C default for `out_layout` from `"NHWC"` to match `in_layout` when absent.
> After that fix, models whose output layout matches their input layout (the majority) can safely omit this field.

---

### `out_precision`
Element type of the output tensor.  
**Type:** string or absent  
**Supported values:** `"fp32"`, `"u8"`, `"u16"`  
**Default (if absent):** `"fp32"` — confirmed safe; the C struct is explicitly initialized to `"fp32"` before the JSON is applied.  
**When to set:** only needed if the model outputs integer data (`"u8"` or `"u16"`). All currently shipped models use `"fp32"` and can omit this field once the comparison table below is read.

---

### `out_precision_depth_derived`
When `true`, the output precision is derived from the frame bit depth instead of `out_precision`: 8-bit frames → `u8`, 10/16-bit frames → `u16`.  
**Type:** boolean  
**Default (if absent):** `false`  
**When to set:** `true` for legacy EDSR integer-output variants only. All current shipped configs set this to `false`.

---

### `model_color`
Colour space string sent to the iVSR SDK to describe the input tensor's colour format.  
**Type:** string or absent  
**Supported values:** `"RGB"`, `"I420_Three_Planes"`

| Value | Meaning |
|---|---|
| `"RGB"` | Model expects interleaved RGB planes |
| `"I420_Three_Planes"` | Model expects YUV 4:2:0 three-plane layout |

**Default (if absent):** no colour format is written to the SDK — **this causes undefined behaviour** if `color_format_auto` is also `0` (the default). Always set either `model_color` or `color_format_auto`.

> **TODO:** Change the C default so that when `model_color` is absent and `color_format_auto` is `0`, the SDK receives `"RGB"` automatically.
> After that fix, all standard RGB models can omit this field.

---

### `out_order`
Output channel order used when writing pixels back into the FFmpeg frame buffer.  
**Type:** string  
**Supported values:** `"RGB"`, `"BGR"`, `"NONE"`  
**Default (if absent):** `"RGB"`  
**When to set:** `"NONE"` for single-channel (luma-only) models like CustVSR, where no colour reordering applies.

---

### `window_type`
Frame queuing strategy used to assemble the input tensor.

| Value | Behaviour | Used by |
|---|---|---|
| `"single"` | No queue; one frame is fed directly into the tensor per inference call | EDSR, SPAN, VideoSeal, VideoProc, CustVSR |
| `"sliding"` | A sliding window of `nif` frames is maintained in a queue; oldest frame is dropped after each call | RIFE, TSENet |
| `"in_queue"` | `nif` frames are read from the task's input queue (BasicVSR built-in path; not for JSON configs) | BasicVSR only |

**Default (if absent):** `"single"`

---

### `window_init_dup`
Only relevant when `window_type` is `"sliding"`.  
When `true`, the first frame is duplicated to prime the sliding window so inference can begin immediately without waiting for `nif` distinct frames.  
**Type:** boolean  
**Default (if absent):** `false`  
**When to set:** `true` for TSENet (temporal continuity at stream start). `false` for RIFE (interpolation genuinely requires two distinct frames).

---

### `normalize_input`
When `true`, uint8 pixel values [0, 255] are divided by 255 before being packed into the float32 input tensor, producing a [0.0, 1.0] range.  
When `false`, raw pixel values are packed as-is into float32.  
**Type:** boolean  
**Default (if absent):** `true` (**⚠️ unsafe default**)

> **TODO:** Change the C default for `normalize_input` from `true` to `false`.
> Rationale: 5 out of 7 shipped models need `false`. The current default silently corrupts output
> for VideoSeal, EDSR, VideoProc, and CustVSR if this field is accidentally omitted.
> After the fix, only RIFE and SPAN need to explicitly set `"normalize_input": true`.

---

### `normalize_output`
When `true`, float32 output values are multiplied by 255 and clipped to [0, 255] before being written into the output frame.  
When `false`, float32 values are rounded and clipped directly.  
**Type:** boolean  
**Default (if absent):** `true` (**⚠️ unsafe default** — same reason as `normalize_input`)

> **TODO:** Change the C default for `normalize_output` from `true` to `false`.
> After the fix, only RIFE, SPAN, and TSENet need to explicitly set `"normalize_output": true`.

---

### `output_passthrough_dims`
When `true`, the output frame dimensions are forced to match the input frame dimensions, regardless of what the model's output tensor reports.  
Used for watermarking and passthrough models where the spatial size never changes.  
**Type:** boolean  
**Default (if absent):** `false`  
**When to set:** `true` for VideoSeal and VideoProc.

---

### `color_format_auto`
Controls how the colour space string is determined when `model_color` is absent.  
Takes priority over `model_color` being set when the value is non-zero.

| Value | Behaviour | Used by |
|---|---|---|
| `0` | Use the `model_color` string directly | All standard RGB models |
| `1` | Auto-detect from the input pixel format: RGB input → `"RGB"`, YUV input → `"I420_Three_Planes"` | VideoProc |
| `2` | Always `"I420_Three_Planes"` regardless of input format | CustVSR |

**Default (if absent):** `0`  
**When to set:** `1` for models that accept both RGB and YUV input; `2` for YUV-only models.

---

## Model parameter comparison

| Parameter | RIFE | VideoSeal | TSENet | EDSR | VideoProc | CustVSR | SPAN |
|---|---|---|---|---|---|---|---|
| **name** | `"RIFE"` | `"VideoSeal"` | `"TSENet"` | `"Enhanced EDSR"` | `"VideoProc"` | `"Custom VSR"` | `"SPAN"` |
| **nif** | `2` | `1` | `3` | `1` | `1` | `1` | `1` |
| **channel_divisor** | `2` | *(absent→1)* | `3` | *(absent→1)* | *(absent→1)* | *(absent→1)* | *(absent→1)* |
| **align** | `128` | `0` | `0` | `0` | `64` | `0` | `0` |
| **in_layout** | `NCHW` | `NCHW` | `NCHW` | `NCHW` | `NHWC` | `NCHW` | `NCHW` |
| **in_precision** | `f32` | `f32` | *(absent)* | `f32` | *(absent)* | *(absent)* | `f32` |
| **out_layout** | `NCHW` | `NCHW` | `NHWC` | `NCHW` | `NHWC` | `NCHW` | `NCHW` |
| **out_precision** | `fp32` | `fp32` | `fp32` | `fp32` | `fp32` | `fp32` | `fp32` |
| **model_color** | `RGB` | `RGB` | `RGB` | `RGB` | *(absent)* | *(absent)* | `RGB` |
| **out_order** | `RGB` | `RGB` | `RGB` | `RGB` | *(absent→RGB)* | `NONE` | `RGB` |
| **window_type** | `sliding` | `single` | `sliding` | `single` | `single` | `single` | `single` |
| **window_init_dup** | `false` | `false` | `true` | `false` | `false` | `false` | `false` |
| **normalize_input** | `true` | `false` | `false` | `false` | `false` | `false` | `true` |
| **normalize_output** | `true` | `false` | `true` | `false` | `false` | `false` | `true` |
| **output_passthrough_dims** | `false` | `true` | `false` | `false` | `true` | `false` | `false` |
| **out_precision_depth_derived** | `false` | `false` | `false` | `false` | `false` | `false` | `false` |
| **color_format_auto** | `0` | `0` | `0` | `0` | `1` | `2` | `0` |

---

## Summary of safe defaults (current state)

| Parameter | C default | Safe to omit today? |
|---|---|---|
| `name` | — | ❌ required |
| `in_layout` | — | ❌ required |
| `nif` | `1` | ✅ for single-frame models |
| `channel_divisor` | `1` | ✅ when no channel stacking |
| `align` | `0` | ✅ when no alignment needed |
| `in_precision` | depth-derived | ✅ when depth-derived is correct |
| `out_layout` | `"NHWC"` | ⚠️ only safe for NHWC output models; NCHW models must set it |
| `out_precision` | `"fp32"` | ✅ for all currently shipped models |
| `model_color` | empty string | ⚠️ unsafe — must set either this or `color_format_auto` |
| `out_order` | `"RGB"` | ✅ except `"NONE"` for luma-only models |
| `window_type` | `"single"` | ✅ for single-frame models |
| `window_init_dup` | `false` | ✅ when false |
| `normalize_input` | `true` | ⚠️ unsafe — most models need `false` |
| `normalize_output` | `true` | ⚠️ unsafe — most models need `false` |
| `output_passthrough_dims` | `false` | ✅ when false |
| `out_precision_depth_derived` | `false` | ✅ always for current models |
| `color_format_auto` | `0` | ✅ when using `model_color` |
