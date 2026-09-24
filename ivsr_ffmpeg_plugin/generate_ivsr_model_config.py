#!/usr/bin/env python3
"""
generate_ivsr_model_config.py
─────────────────────────────
Auto-generate an iVSR JSON model config file from an OpenVINO IR .xml file.

The tool reads the Parameter (input) and Result (output) layers from the IR,
infers as many config fields as possible from the tensor shapes and types,
always displays a full IR analysis summary with warnings, and interactively
prompts only for the fields that cannot be determined from the model structure.

Usage
-----
  # Recommended: interactive mode
  python3 generate_ivsr_model_config.py model.xml

  # Fully automatic (for CI / scripted pipelines)
  python3 generate_ivsr_model_config.py model.xml --non-interactive

  # Override output path and model name
  python3 generate_ivsr_model_config.py model.xml -o configs/my_model.json -n "MyModel"

  # Validate the generated config
  jsonschema -i my_model_config.json ivsr_model_config.schema.json

JSON fields produced
--------------------
  name                     Human-readable label (log messages)
  nif                      Frames consumed per inference call
  align                    Input W/H alignment padding (0 = none)
  in_layout                Input tensor layout: NCHW | NHWC | NFHWC
  in_precision             Input element type: f32 | u8 | u16 | null
  out_layout               Output tensor layout
  out_precision            Output element type: fp32 | u8 | u16 | null
  model_color              SDK color space: RGB | I420_Three_Planes | null
  out_order                Output channel order: RGB | BGR | NONE
  window_type              Frame queuing: single | sliding | in_queue
  window_init_dup          Duplicate first frame for sliding window prime
  normalize_input          Divide uint8 pixels by 255 before float packing
  normalize_output         Multiply float output by 255 after inference
  output_passthrough_dims  Output W/H == input W/H (passthrough models)
  out_precision_depth_derived  Derive output precision from frame bit depth
"""

import argparse
import json
import os
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


# ─────────────────────────────────────────────────────────────────────────────
# Section 1: OpenVINO IR XML parsing
# ─────────────────────────────────────────────────────────────────────────────

def _parse_dims(port_el: ET.Element) -> List[int]:
    """Return a list of ints from <dim> children; -1 for dynamic/unknown dims."""
    dims = []
    for d in port_el.findall("dim"):
        try:
            dims.append(int(d.text.strip()))
        except (ValueError, AttributeError):
            dims.append(-1)
    return dims


def parse_ir(xml_path: str) -> Tuple[List[Dict], List[Dict]]:
    """
    Parse an OpenVINO IR .xml and return:
      inputs:  list of {"name", "shape", "element_type"}
      outputs: list of {"name", "shape", "precision"}

    Works with OpenVINO IR version 10 and 11 (opset-based IR).
    """
    tree = ET.parse(xml_path)
    root = tree.getroot()  # <net>

    # Build layer-id → element map for cross-referencing edges
    layers_by_id: Dict[str, ET.Element] = {}
    for layer in root.iter("layer"):
        lid = layer.get("id")
        if lid is not None:
            layers_by_id[lid] = layer

    # Build edge map: (to_layer_id, to_port_id) → (from_layer_id, from_port_id)
    edges: Dict[Tuple[str, str], Tuple[str, str]] = {}
    for edge in root.iter("edge"):
        key = (edge.get("to-layer"), edge.get("to-port"))
        edges[key] = (edge.get("from-layer"), edge.get("from-port"))

    inputs: List[Dict] = []
    outputs: List[Dict] = []

    for layer in root.iter("layer"):
        ltype = layer.get("type")
        lid = layer.get("id", "")
        lname = layer.get("name", "")

        # ── Input layer ──────────────────────────────────────────────────────
        if ltype == "Parameter":
            data_el = layer.find("data")
            # OV IR stores shape/element_type as attributes on <data>
            shape_str = data_el.get("shape", "") if data_el is not None else ""
            element_type = (
                data_el.get("element_type", "f32") if data_el is not None else "f32"
            )

            # Parse shape from the <data shape="N,C,H,W"> attribute (most reliable)
            if shape_str:
                shape = []
                for s in shape_str.replace(" ", "").split(","):
                    try:
                        shape.append(int(s))
                    except ValueError:
                        shape.append(-1)
            else:
                # Fallback: read from output port dims
                out_port = None
                output_el = layer.find("output")
                if output_el is not None:
                    out_port = output_el.find("port")
                shape = _parse_dims(out_port) if out_port is not None else []

            # Extract the tensor name from the output port's "names" attribute
            out_port = None
            output_el = layer.find("output")
            if output_el is not None:
                out_port = output_el.find("port")
            tensor_name = (
                out_port.get("names", lname) if out_port is not None else lname
            )

            inputs.append(
                {"name": tensor_name, "shape": shape, "element_type": element_type}
            )

        # ── Output layer ─────────────────────────────────────────────────────
        elif ltype == "Result":
            inp_el = layer.find("input")
            port = inp_el.find("port") if inp_el is not None else None
            precision = port.get("precision", "FP32") if port is not None else "FP32"
            shape = _parse_dims(port) if port is not None else []

            out_names = layer.get("output_names", lname)

            # If Result port dims are all dynamic, trace back through edges to get
            # the actual shape from the feeding layer's output port.
            if not shape or all(d <= 0 for d in shape):
                from_info = edges.get((lid, "0"))
                if from_info:
                    from_layer = layers_by_id.get(from_info[0])
                    if from_layer is not None:
                        out_el = from_layer.find("output")
                        if out_el is not None:
                            for p in out_el.findall("port"):
                                if p.get("id") == from_info[1]:
                                    candidate = _parse_dims(p)
                                    if candidate and any(d > 0 for d in candidate):
                                        shape = candidate
                                        precision = p.get("precision", precision)
                                    break

            outputs.append({"name": out_names, "shape": shape, "precision": precision})

    return inputs, outputs


def scan_early_ops(xml_path: str, max_ops: int = 20) -> Dict[str, bool]:
    """
    Fast heuristic scan of the IR's Parameter/Result layers.
    Returns a dict of clues:
      "multi_input"        — model has more than one Parameter (conditioning inputs)
      "multi_output"        — model has more than one Result layer

    NOTE: an earlier version of this scan also flagged "has_early_divide" /
    "has_early_subtract" whenever ANY Divide/Multiply/Subtract/Add op appeared
    in the first `max_ops` layers, and used that to guess normalize_input.
    That signal is unreliable: it matches unrelated ops (Conv bias-Add,
    floor_divide shape arithmetic) and was empirically wrong for SPAN/HDRTVNet.
    See detect_input_normalization_constant() for the constant-value-based
    replacement, which only fires on the exact op feeding the Parameter.
    """
    tree = ET.parse(xml_path)
    root = tree.getroot()

    clues: Dict[str, bool] = {
        "multi_input": False,
        "multi_output": False,
    }

    param_count = sum(1 for layer in root.iter("layer") if layer.get("type") == "Parameter")
    result_count = sum(1 for layer in root.iter("layer") if layer.get("type") == "Result")

    clues["multi_input"] = param_count > 1
    clues["multi_output"] = result_count > 1
    return clues


# Element types (as they appear on <data element_type="..."> for Const layers)
# that we know how to unpack as native floats via struct, plus (struct_char, byte_size).
_CONST_FLOAT_FORMATS = {
    "f32": ("f", 4), "fp32": ("f", 4),
    "f16": ("e", 2), "fp16": ("e", 2),
    "f64": ("d", 8), "fp64": ("d", 8),
}

# Ops whose second operand (if a small Const) reveals the input's expected
# pixel-value range.
_NORMALIZATION_OP_TYPES = {"Divide", "Multiply", "Subtract", "Add"}
_PASSTHROUGH_OP_TYPES = {"Convert", "Reshape", "Squeeze", "Unsqueeze"}


def _resolve_to_const(
    layers_by_id: Dict[str, ET.Element],
    edges: Dict[Tuple[str, str], Tuple[str, str]],
    layer_id: str,
    port: str,
    max_hops: int = 3,
) -> Optional[str]:
    """Follow a (layer_id, port) input back through Convert/Reshape ops to find
    the id of the Const layer that ultimately feeds it, or None if it doesn't
    terminate in a Const within max_hops."""
    cur_layer, cur_port = layer_id, port
    for _ in range(max_hops):
        from_info = edges.get((cur_layer, cur_port))
        if not from_info:
            return None
        from_layer, _from_port = from_info
        layer = layers_by_id.get(from_layer)
        if layer is None:
            return None
        ltype = layer.get("type")
        if ltype == "Const":
            return from_layer
        if ltype in _PASSTHROUGH_OP_TYPES:
            cur_layer, cur_port = from_layer, "0"
            continue
        return None
    return None


def detect_input_normalization_constant(
    xml_path: str,
) -> Tuple[Optional[str], Optional[List[float]]]:
    """
    Find the literal constant baked into any Divide/Multiply/Subtract/Add op
    that sits directly on the input path (Parameter -> [Convert/Reshape]* ->
    op), and return (op_type, values) read straight from the sibling .bin
    weights file. Returns (None, None) if no such op/constant is found.

    This targets the *exact* op consuming the model's raw pixel tensor, unlike
    a generic "any Divide/Subtract in the first N layers" scan — which also
    matches unrelated ops (conv bias-Add, floor_divide shape math) and gives
    false positives. Verified empirically against shipped models:
      VideoSeal: Parameter -> Divide(255.0)                 -> raw [0,255] scale
      SPAN:      Parameter -> Add(-0.449,-0.437,-0.404)      -> ImageNet-style
                                                                 per-channel mean
    """
    try:
        tree = ET.parse(xml_path)
    except (ET.ParseError, OSError):
        return None, None
    root = tree.getroot()

    layers_by_id = {l.get("id"): l for l in root.iter("layer")}
    edges: Dict[Tuple[str, str], Tuple[str, str]] = {}
    consumers: Dict[str, List[Tuple[str, str]]] = {}
    for e in root.iter("edge"):
        to_layer, to_port = e.get("to-layer"), e.get("to-port")
        from_layer, from_port = e.get("from-layer"), e.get("from-port")
        edges[(to_layer, to_port)] = (from_layer, from_port)
        consumers.setdefault(from_layer, []).append((to_layer, to_port))

    param_id = next((l.get("id") for l in root.iter("layer") if l.get("type") == "Parameter"), None)
    if param_id is None:
        return None, None

    # BFS from the Parameter through passthrough ops (Convert/Reshape/...) only,
    # looking for the first real math op that could be a normalization step.
    frontier = [param_id]
    visited = set()
    op_id = op_type = None
    for _ in range(4):
        next_frontier = []
        for lid in frontier:
            if lid in visited:
                continue
            visited.add(lid)
            for to_layer, _to_port in consumers.get(lid, []):
                clayer = layers_by_id.get(to_layer)
                if clayer is None:
                    continue
                ctype = clayer.get("type")
                if ctype in _NORMALIZATION_OP_TYPES:
                    op_id, op_type = to_layer, ctype
                    break
                if ctype in _PASSTHROUGH_OP_TYPES:
                    next_frontier.append(to_layer)
            if op_id:
                break
        if op_id:
            break
        frontier = next_frontier

    if not op_id:
        return None, None

    const_layer_id = _resolve_to_const(layers_by_id, edges, op_id, "0") or \
        _resolve_to_const(layers_by_id, edges, op_id, "1")
    if not const_layer_id:
        return None, None

    data_el = layers_by_id[const_layer_id].find("data")
    if data_el is None or data_el.get("offset") is None:
        return None, None
    try:
        offset = int(data_el.get("offset"))
        size = int(data_el.get("size"))
    except (TypeError, ValueError):
        return None, None
    et = (data_el.get("element_type") or "f32").lower()

    fmt = _CONST_FLOAT_FORMATS.get(et)
    # Only scalar/small per-channel constants are normalization values; a huge
    # tensor here means we followed the wrong operand (e.g. conv weights).
    if not fmt or size <= 0 or size > 256 or size % fmt[1] != 0:
        return None, None

    bin_path = Path(xml_path).with_suffix(".bin")
    if not bin_path.is_file():
        return None, None
    try:
        with open(bin_path, "rb") as f:
            f.seek(offset)
            raw = f.read(size)
        n = size // fmt[1]
        values = list(struct.unpack(f"<{n}{fmt[0]}", raw))
    except (OSError, struct.error):
        return None, None

    return op_type, values


def classify_input_normalization(op_type: Optional[str], values: Optional[List[float]]) -> Optional[str]:
    """
    Classify a detected input-side constant as:
      "raw_255_scale"     — Divide by ~255 (or Multiply by ~1/255): the model
                             internally rescales raw [0,255] pixels itself, so
                             the FFmpeg plugin must NOT pre-divide -> normalize_input=False
      "meanstd_normalize" — Subtract/Add/Divide/Multiply by a small (<3) value:
                             ImageNet-style per-channel mean/std centering, which
                             only makes sense on already-[0,1] data -> normalize_input=True
      None                — no confident classification (value out of range, or
                             nothing detected)
    """
    if op_type is None or not values:
        return None
    abs_vals = [abs(v) for v in values]
    vmin, vmax = min(abs_vals), max(abs_vals)

    if op_type == "Divide" and 200.0 <= vmin <= vmax <= 300.0:
        return "raw_255_scale"
    if op_type == "Multiply" and (1 / 300.0) <= vmin <= vmax <= (1 / 200.0):
        return "raw_255_scale"
    if op_type in ("Subtract", "Add", "Divide", "Multiply") and 0.01 <= vmin <= vmax <= 3.0:
        return "meanstd_normalize"
    return None



# ─────────────────────────────────────────────────────────────────────────────
# Section 2: Heuristic analysis of tensor shapes
# ─────────────────────────────────────────────────────────────────────────────

def detect_layout(shape: List[int]) -> Tuple[str, int]:
    """
    Given a tensor shape [N, ...], return (layout_string, channels_per_frame).

    Layout detection heuristic:
      - 4-D NCHW: shape[1] (C) is small (≤16), shape[2]/shape[3] (H/W) are large
      - 4-D NHWC: shape[3] (C) is small (≤16), shape[1]/shape[2] (H/W) are large
      - 5-D NFHWC: shape[4] (C) is small; shape[1] (F) is the frame count
      - 5-D NFCHW: shape[2] (C) is small; shape[1] (F) is the frame count

    Returns layout string and the channel-per-frame count (may be -1 if dynamic).
    """
    CHANNEL_THRESHOLD = 16  # channels are always ≤ 16 for RGB/YUV/RGBA frames

    if len(shape) == 4:
        c_pos1 = shape[1]  # candidate C for NCHW
        c_pos3 = shape[3]  # candidate C for NHWC

        # Both dynamic: can't distinguish — default to NCHW (more common for SR)
        if c_pos1 <= 0 and c_pos3 <= 0:
            return "NCHW", -1

        # Clear NHWC signal: last dim is small and positive
        if c_pos3 > 0 and c_pos3 <= CHANNEL_THRESHOLD:
            if c_pos1 <= 0 or c_pos1 > CHANNEL_THRESHOLD:
                return "NHWC", c_pos3

        # Clear NCHW signal: second dim is small and positive
        if c_pos1 > 0 and c_pos1 <= CHANNEL_THRESHOLD:
            return "NCHW", c_pos1

        # Ambiguous (e.g., square shape) — default to NCHW
        return "NCHW", c_pos1

    elif len(shape) == 5:
        # NFHWC: [N, F, H, W, C] — shape[4] is channels
        # NFCHW: [N, F, C, H, W] — shape[2] is channels
        c_pos4 = shape[4]
        c_pos2 = shape[2]
        if c_pos4 > 0 and c_pos4 <= CHANNEL_THRESHOLD:
            return "NFHWC", c_pos4
        if c_pos2 > 0 and c_pos2 <= CHANNEL_THRESHOLD:
            return "NFCHW", c_pos2
        return "NFHWC", c_pos4

    elif len(shape) == 3:
        # N, H, W (grayscale single frame) or N, C, HW — rare
        return "NHW", 1

    # Fallback
    return "NCHW", -1


def detect_nif(layout: str, shape: List[int]) -> Tuple[int, int]:
    """
    Return (nif, channels_per_frame) based on layout and input shape.

    For NCHW:  total_channels = shape[1]; nif = total_channels / 3 (or /1 for gray)
    For NHWC:  total_channels = shape[3]; same logic
    For NFHWC: shape[1] = F = nif directly; shape[4] = channels_per_frame
    For NFCHW: shape[1] = F = nif; shape[2] = channels_per_frame
    """
    if layout in ("NFHWC",):
        f = shape[1] if len(shape) > 1 and shape[1] > 0 else 1
        c = shape[4] if len(shape) > 4 and shape[4] > 0 else 3
        return f, c

    if layout in ("NFCHW",):
        f = shape[1] if len(shape) > 1 and shape[1] > 0 else 1
        c = shape[2] if len(shape) > 2 and shape[2] > 0 else 3
        return f, c

    if layout == "NCHW":
        total_ch = shape[1] if len(shape) > 1 and shape[1] > 0 else 3
    elif layout == "NHWC":
        total_ch = shape[3] if len(shape) > 3 and shape[3] > 0 else 3
    else:
        total_ch = 3

    # Probe common per-frame channel counts (RGB=3, grayscale=1, RGBA=4)
    for ch_per_frame in (3, 1, 4, 2):
        if total_ch % ch_per_frame == 0:
            return total_ch // ch_per_frame, ch_per_frame

    return 1, total_ch


def detect_channel_divisor(layout: str, nif: int) -> int:
    """
    Return the channel_divisor value required by the JSON config dispatch
    (dnn_backend_ivsr.c: parse_model_config_json / fill_model_input_ivsr).

    When multiple frames are stacked along the channel axis (NCHW/NHWC with
    nif > 1, e.g. RIFE nif=2 -> 6ch, TSENet nif=3 -> 9ch), the SDK reports the
    *total* stacked channel count to FFmpeg unless channel_divisor tells it to
    divide back down to the per-frame count (3 for RGB). Omitting this field
    silently defaults to 1 in the C parser, which breaks tensor/channel
    reporting for any stacked-channel multi-frame model.

    NFHWC/NFCHW layouts already carry frames on a separate axis (BasicVSR-
    style, window_type=in_queue), so no channel division is needed there.
    """
    if nif > 1 and layout in ("NCHW", "NHWC"):
        return nif
    return 1


def map_element_type(et: str) -> str:
    """
    Map OV IR element_type string → iVSR in_precision string.

    OV uses lowercase element_type on <data>: "f32", "u8", "i64", "f16", etc.
    iVSR uses "f32", "u8", "u16" (or null for depth-derived).
    """
    et = et.lower().replace(" ", "")
    if et in ("f32", "fp32", "float32"):
        return "f32"
    if et in ("u8", "uint8"):
        return "u8"
    if et in ("u16", "uint16"):
        return "u16"
    if et in ("f16", "fp16", "float16"):
        # f16 models run as f32 in the iVSR/OV runtime
        return "f32"
    if et in ("bf16", "bfloat16"):
        return "f32"
    # Integer types (i32, i64) are not standard model inputs — fallback safely
    return "f32"


def map_output_precision(prec: str) -> str:
    """Map OV port precision string → iVSR out_precision string."""
    p = prec.upper().replace(" ", "")
    if p in ("FP32", "F32", "FLOAT32"):
        return "fp32"
    if p in ("U8", "UINT8"):
        return "u8"
    if p in ("U16", "UINT16"):
        return "u16"
    if p in ("FP16", "F16"):
        return "fp32"   # cast to fp32 at runtime
    return "fp32"


def detect_scale_from_pixel_shuffle(xml_path: str) -> Tuple[int, int]:
    """
    Detect SR upscale factor from the pixel_shuffle Reshape_1 pattern in OV IR.

    PyTorch pixel_shuffle(x, r) is lowered to:
        Reshape_1:  [N, C*r*r, H, W] → [N, C, r, r, H, W]
        Transpose:  [N, C, r, r, H, W] → [N, C, H, r, W, r]
        Reshape_2:  [N, C, H, r, W, r] → [N, C, H*r, W*r]

    The scale r is always a literal integer in Reshape_1's output dims at
    positions [2] and [3] (the two hardcoded 'r' dims).  It is readable
    directly from the XML without touching the .bin weight file.

    Returns (scale_h, scale_w) — typically (r, r) — or (1, 1) if not found.
    """
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
        for layer in root.iter("layer"):
            name = layer.get("name", "")
            if "pixel_shuffle" not in name:
                continue
            if layer.get("type") != "Reshape":
                continue
            # Reshape_1 has 6-D output: [N, C, r, r, H, W]
            out_port = layer.find(".//output/port")
            if out_port is None:
                continue
            dims = [int(d.text) for d in out_port.findall("dim")]
            if len(dims) == 6 and dims[2] > 0 and dims[3] > 0:
                return dims[2], dims[3]
    except Exception:
        pass
    return 1, 1


def detect_sr_scale(in_shape: List[int], out_shape: List[int]) -> Tuple[int, int]:
    """
    Detect super-resolution upscale factor by comparing spatial dims.
    Returns (scale_h, scale_w); both 1 means passthrough / same-size.
    Handles dynamic (-1) shapes conservatively.
    """
    if not in_shape or not out_shape:
        return 1, 1

    def _spatial_dims(shape):
        """Return (H_idx, W_idx) candidates for NCHW and NHWC."""
        if len(shape) >= 4:
            return [(2, 3), (1, 2)]   # NCHW first, then NHWC
        return []

    for hi, wi in _spatial_dims(in_shape):
        if hi >= len(in_shape) or wi >= len(in_shape):
            continue
        if hi >= len(out_shape) or wi >= len(out_shape):
            continue
        ih, iw = in_shape[hi], in_shape[wi]
        oh, ow = out_shape[hi], out_shape[wi]
        if ih > 0 and iw > 0 and oh > 0 and ow > 0:
            sh = oh // ih if oh > ih else 1
            sw = ow // iw if ow > iw else 1
            return sh, sw

    return 1, 1


def infer_window_type(nif: int, layout: str) -> Tuple[str, bool]:
    """
    Infer window_type and window_init_dup from nif and layout.

    Rules:
      nif == 1              → "single"
      nif == 2, NCHW        → "sliding" (RIFE-style, no dup needed)
      nif >= 3, NFHWC/NFCHW → "in_queue" (BasicVSR-style batched read)
      nif == 3, NCHW        → "sliding" + init_dup=True (TSENet-style)
      nif >= 3, other       → "sliding" + init_dup=True (conservative)
    """
    if nif <= 1:
        return "single", False
    if nif == 2:
        return "sliding", False
    if "NFHWC" in layout or "NFCHW" in layout:
        return "in_queue", False
    # nif ≥ 3 with stacked-channel layout (TSENet-style)
    return "sliding", True


def infer_align(nif: int, in_precision: str, layout: str) -> int:
    """
    Infer alignment padding requirement from known model patterns.

    RIFE (nif=2, f32 NCHW)   → 128 px  (grid_sample requires power-of-2 resolution)
    BasicVSR (NFHWC/NFCHW)   →  32 px
    All others               →   0 (no padding)

    Single-channel Y-plane models (VideoProc, CustVSR) cannot be told apart
    from tensor shape alone: canonical VideoProc needs align=64, canonical
    CustVSR needs align=0. This field is left at 0 by default for those and
    MUST be confirmed manually (see the interactive 'align' prompt).
    """
    if nif == 2 and in_precision == "f32" and "NCHW" in layout:
        return 128
    if "NFHWC" in layout or "NFCHW" in layout:
        return 32
    return 0


def infer_normalize(in_precision: str, norm_signal: Optional[str]) -> Tuple[bool, bool]:
    """
    Infer normalize_input and normalize_output.

    If in_precision is "f32", the C code packs pixels as float and the question
    is whether it should divide by 255 (RIFE/SPAN/HDRTVNet-LE convention, model
    trained on [0,1]) or pass raw [0,255] (VideoProc/EDSR/CustVSR/TSENet-in/
    VideoSeal convention, model trained on [0,255]).

    norm_signal comes from classify_input_normalization() — the literal constant
    baked into whatever Divide/Multiply/Subtract/Add op sits directly on the
    Parameter's input path (read from the .bin weights, not just op-type
    pattern matching):
      "raw_255_scale"     — confirmed Divide/Multiply by ~255: the model itself
                             rescales raw [0,255] pixels -> normalize_input=False
      "meanstd_normalize" — confirmed small (<3) mean/std constant: only valid
                             on already-[0,1] data -> normalize_input=True
      None                — no op sits on the raw input at all (goes straight
                             into e.g. Convolution/Slice). This is genuinely
                             indistinguishable from the IR: HDRTVNet-LE/RIFE
                             (True) and EDSR/TSENet-input (False) have an
                             identical "no preprocessing op" structure. Default
                             to False (matches the corrected C-side default,
                             patch 0006) and require manual confirmation.
    If in_precision is "u8" or "u16":
      - The generic SDK path handles normalization; normalize_input applies only
        to the pack_input_window() custom float path.  Irrelevant, but we keep
        it False to avoid confusion.
    """
    if in_precision in ("u8", "u16"):
        return False, False

    if norm_signal == "raw_255_scale":
        return False, False
    if norm_signal == "meanstd_normalize":
        return True, True
    # No confident signal in the IR — safe majority default, must be confirmed.
    return False, False


# ─────────────────────────────────────────────────────────────────────────────
# Section 3: Interactive prompts
# ─────────────────────────────────────────────────────────────────────────────

def _ask(prompt: str, default: Any, choices: Optional[List[str]] = None) -> str:
    """Print a prompt, return user input or default on empty/EOF."""
    if choices:
        choices_display = "/".join(
            f"[{c}]" if str(c) == str(default) else str(c) for c in choices
        )
        full_prompt = f"  {prompt} ({choices_display}): "
    else:
        full_prompt = f"  {prompt} [default: {default}]: "

    try:
        ans = input(full_prompt).strip()
    except (EOFError, KeyboardInterrupt):
        print()
        return str(default)

    return ans if ans else str(default)


def _ask_bool(prompt: str, default: bool) -> bool:
    ans = _ask(prompt, "true" if default else "false", choices=["true", "false"])
    return ans.lower() in ("true", "1", "yes", "y")


def _ask_int(prompt: str, default: int) -> int:
    while True:
        ans = _ask(prompt, str(default))
        try:
            return int(ans)
        except ValueError:
            print(f"    ↳ '{ans}' is not an integer — please try again.")


# ─────────────────────────────────────────────────────────────────────────────
# Section 4: Parameter-by-parameter documentation (deep dive)
# ─────────────────────────────────────────────────────────────────────────────

PARAM_DOCS = {
    "name": (
        "Human-readable label embedded in FFmpeg log messages.\n"
        "  Used by: av_log() calls inside ff_dnn_load_model_ivsr() and\n"
        "           fill_model_input_ivsr() for error/debug output.\n"
        "  No functional effect on inference."
    ),
    "nif": (
        "Number of input frames consumed per inference call.\n"
        "  Stored in IVSRModel.nif (overrides SDK-reported value when > 0).\n"
        "  Used by: fill_model_input_ivsr() — controls how many frames are\n"
        "    read from task->in_queue (in_queue mode) or frame_queue (sliding).\n"
        "  Also passed to pack_input_* functions as m->nif.\n"
        "  Set to 1 for single-frame models, 2 for RIFE, 3 for TSENet/BasicVSR."
    ),
    "channel_divisor": (
        "Divides the SDK-reported tensor channel count so FFmpeg sees a\n"
        "  standard 3-channel (RGB) frame instead of nif stacked frames.\n"
        "  Parsed in parse_model_config_json() (MKEY(\"channel_divisor\")) and\n"
        "  applied in fill_model_input_ivsr() / get_input_ivsr():\n"
        "    int div = get_model_desc(ivsr_model)->channel_divisor;\n"
        "    if (div > 1) { input.dims[channel_idx] /= div; input.channels /= div; }\n"
        "  Required whenever nif > 1 frames are stacked on the channel axis\n"
        "  (NCHW/NHWC layout): RIFE (nif=2) uses 2, TSENet (nif=3) uses 3.\n"
        "  Defaults to 1 in the C parser when omitted — leaving it out for a\n"
        "  stacked-channel model silently reports the wrong channel count.\n"
        "  1 for all single-frame or NFHWC/NFCHW (in_queue) models."
    ),
    "align": (
        "Rounds input W and H up to the nearest multiple of this value.\n"
        "  Applied in ff_dnn_load_model_ivsr():\n"
        "    if (a > 0) { frame_h = (frame_h + a-1)/a*a; ... }\n"
        "  The aligned resolution is passed to ivsr_init() as RESHAPE_SETTINGS.\n"
        "  The difference (padded_size - actual_size) is zero-filled by\n"
        "  set_padding_value() in fill_model_input_ivsr().\n"
        "  0 = no padding. RIFE needs 128 (grid_sample). BasicVSR needs 32."
    ),
    "in_layout": (
        "Tensor memory layout passed to the iVSR SDK as INPUT_TENSOR_DESC_SETTING.\n"
        "  Applied in ff_dnn_load_model_ivsr():\n"
        "    strcpy(input_tensor_desc_set.layout, md->in_layout);\n"
        "  The SDK uses this to configure the OV inference request input.\n"
        "  Also used by set_dnndata_info() to populate DNNData.layout,\n"
        "  which controls NCHW↔NHWC conversion in fill_model_input_ivsr().\n"
        "  NCHW: standard for CNN models (PyTorch default)\n"
        "  NHWC: TensorFlow-style; also used by some ONNX exports\n"
        "  NFHWC: multi-frame batched layout (BasicVSR)"
    ),
    "in_precision": (
        "Input tensor element type passed to the iVSR SDK.\n"
        "  Applied in ff_dnn_load_model_ivsr():\n"
        "    if (md->in_precision) strcpy(input_tensor_desc_set.precision, md->in_precision);\n"
        "  null → depth-derived: u8 for 8-bit frames, u16 for 10/16-bit.\n"
        "  f32  → model expects float32 input; C code uses pack_input_window()\n"
        "         which optionally divides by 255 (normalize_input flag).\n"
        "  u8/u16 → SDK handles normalization via scale field in tensor_desc."
    ),
    "out_layout": (
        "Output tensor layout passed to the iVSR SDK as OUTPUT_TENSOR_DESC_SETTING.\n"
        "  Applied in ff_dnn_load_model_ivsr():\n"
        "    if (md->out_layout) strcpy(output_tensor_desc_set.layout, md->out_layout);\n"
        "  Used by set_dnndata_info() in infer_completion_callback() to populate\n"
        "  DNNData.layout for the output tensor.\n"
        "  If NCHW and the generic path is used, convert_nchw_to_nhwc() is called\n"
        "  before ff_proc_from_dnn_to_frame()."
    ),
    "out_precision": (
        "Output tensor element type passed to the iVSR SDK.\n"
        "  Applied in ff_dnn_load_model_ivsr():\n"
        "    if (md->out_precision) strcpy(output_tensor_desc_set.precision, md->out_precision);\n"
        "  null → defaults to fp32.\n"
        "  Overridden by out_precision_depth_derived when that flag is true."
    ),
    "model_color": (
        "Color space string set on input_tensor_desc_set.model_color_format.\n"
        "  Applied in ff_dnn_load_model_ivsr():\n"
        "    if (md->model_color) strcpy(input_tensor_desc_set.model_color_format, ...);\n"
        "  Tells the iVSR SDK what color space the model was trained on, so it\n"
        "  can perform any needed color conversion internally.\n"
        "  RGB              → standard RGB (RIFE, SPAN, EDSR, VideoSeal)\n"
        "  I420_Three_Planes → YUV 4:2:0 planar (VideoProc, CustVSR)\n"
        "  null             → color_format_auto logic kicks in:\n"
        "                     0=no override, 1=auto from pixel format, 2=always YUV"
    ),
    "out_order": (
        "DNNColorOrder for DNNData.order in infer_completion_callback().\n"
        "  Set as: output.order = get_model_desc(ivsr_model)->out_order;\n"
        "  Used by ff_proc_from_dnn_to_frame() (generic output path) to determine\n"
        "  the channel order when writing to the AVFrame.\n"
        "  RGB  → output channels are R,G,B (most models)\n"
        "  BGR  → output channels are B,G,R\n"
        "  NONE → no channel reordering (grayscale, or custom unpack_output handles it)"
    ),
    "window_type": (
        "Frame queuing strategy — controls how frames are fed to the model.\n"
        "  Dispatched in pack_input_window() via a switch statement:\n"
        "\n"
        "  single:\n"
        "    No queue. One AVFrame in → immediate inference.\n"
        "    Used by SPAN, VideoSeal, EDSR, HDRTVNet++ LE.\n"
        "    pack_input_window() WINDOW_SINGLE branch runs.\n"
        "\n"
        "  sliding:\n"
        "    Maintains an AVFifo (m->frame_queue) of the last nif frames.\n"
        "    Returns DNN_MORE_FRAMES until nif frames are queued.\n"
        "    After each inference, the oldest frame is popped (slide forward).\n"
        "    Used by RIFE (nif=2) and TSENet (nif=3).\n"
        "    window_init_dup=true duplicates the first frame to prime the queue\n"
        "    (so output starts at frame 1, not frame nif).\n"
        "\n"
        "  in_queue:\n"
        "    Reads nif frames directly from task->in_queue (filled by the filter).\n"
        "    Routes to pack_input_basicvsr() internally.\n"
        "    Used by BasicVSR (nif=3, NFHWC layout)."
    ),
    "window_init_dup": (
        "Only meaningful when window_type == 'sliding'.\n"
        "  Checked in pack_input_window() WINDOW_SLIDING branch:\n"
        "    if (md->sliding_window_init_dup && m->sliding_window_frame_num == 0) {\n"
        "        // duplicate first frame to prime the window\n"
        "    }\n"
        "  true  → frame 1 is duplicated so the window fills immediately,\n"
        "          and inference starts from the very first input frame.\n"
        "          TSENet behaviour: the [prev, curr] window is [frame1, frame1].\n"
        "  false → window fills naturally; first output is produced after nif\n"
        "          distinct frames have been received.\n"
        "          RIFE behaviour: first output is the interpolated frame between\n"
        "          frame 1 and frame 2."
    ),
    "normalize_input": (
        "Whether to divide uint8 pixel values by 255.0 before packing into float32.\n"
        "  Checked in pack_input_window() WINDOW_SINGLE branch:\n"
        "    if (md->normalize_input) {\n"
        "        dst[...] = row[...] / 255.0f;  // [0,1] range\n"
        "    } else {\n"
        "        dst[...] = (float)row[...];    // [0,255] range\n"
        "    }\n"
        "  Only active when in_precision == f32 (custom pack_input_window path).\n"
        "  Default is False in the C parser (patch 0006) — the earlier True\n"
        "  default silently corrupted VideoProc/EDSR/CustVSR/VideoSeal output.\n"
        "  Detection: detect_input_normalization_constant() reads the actual\n"
        "  Divide/Multiply/Subtract/Add constant (if any) baked directly onto\n"
        "  the Parameter's input path from the .bin weights file:\n"
        "    constant ≈ 255            → raw [0,255] scale  → false (confident)\n"
        "    constant ≈ 0.01-3.0       → mean/std normalize → true  (confident)\n"
        "    no such op on raw input   → no signal, defaults false (unconfirmed)\n"
        "  The 'no op' case is genuinely ambiguous from the IR alone: HDRTVNet-LE\n"
        "  (true) and EDSR (false) have an identical 'no preprocessing op' graph\n"
        "  shape, because the [0,1]/[0,255] convention is usually applied by\n"
        "  external preprocessing (e.g. torchvision.ToTensor()) that never gets\n"
        "  traced into the exported ONNX/IR graph — confirm manually in that case.\n"
        "  true  → model trained on [0,1] input (RIFE, SPAN, HDRTVNet-LE)\n"
        "  false → model trained on [0,255] input (VideoProc, EDSR, CustVSR,\n"
        "          TSENet input, VideoSeal — majority of shipped models)"
    ),
    "normalize_output": (
        "Whether to multiply float32 output by 255 before clipping to uint8.\n"
        "  Checked in unpack_output_window():\n"
        "    if (md->normalize_output) {\n"
        "        pixel = (uint8_t)av_clip((int)(val * 255.0f + 0.5f), 0, 255);\n"
        "    } else {\n"
        "        pixel = (uint8_t)av_clip((int)(val + 0.5f), 0, 255);\n"
        "    }\n"
        "  Default is False in the C parser (patch 0006).\n"
        "  Auto-set alongside normalize_input from the same input-side constant\n"
        "  detection (meanstd_normalize implies both true); there is no separate\n"
        "  output-side constant scan, so this is only as confident as the input\n"
        "  detection was — always confirm output range against the canonical\n"
        "  shipped config for your model family when in doubt (e.g. TSENet needs\n"
        "  normalize_input=false / normalize_output=true, which no input-side\n"
        "  scan alone could ever derive).\n"
        "  true  → model output is in [0,1] range (RIFE, SPAN, TSENet, HDRTVNet-LE)\n"
        "  false → model output is already in [0,255] range (VideoProc, EDSR,\n"
        "          CustVSR, VideoSeal)\n"
        "  Not required to match normalize_input — e.g. TSENet uses\n"
        "  normalize_input=false / normalize_output=true."
    ),
    "output_passthrough_dims": (
        "Report output W/H == input W/H regardless of the model's output tensor size.\n"
        "  Used in get_output_ivsr():\n"
        "    if (get_model_desc(ivsr_model)->output_passthrough_dims) {\n"
        "        *output_height = input_height;\n"
        "        *output_width  = input_width;\n"
        "    }\n"
        "  Needed for models where the output tensor is the same resolution as\n"
        "  the input but the tensor metadata doesn't reflect the padded dimensions.\n"
        "  VideoProc uses this because its output is aligned/padded like the input.\n"
        "  false for all super-resolution models (output is larger than input)."
    ),
    "color_format_auto": (
        "Integer controlling how model_color_format is set when model_color is null.\n"
        "  Parsed in parse_model_config_json() and consumed in ff_dnn_load_model_ivsr():\n"
        "    if (md->model_color)           → use model_color string directly (ignore this field)\n"
        "    else if (color_format_auto==1) → VideoProc-auto: 'RGB' or 'I420_Three_Planes'\n"
        "                                    based on the input pixel format flags.\n"
        "    else if (color_format_auto==2) → CustVSR-auto: always 'I420_Three_Planes'.\n"
        "  0 (default) — model_color string is used; this field is irrelevant.\n"
        "  1           — set for VideoProc (model_color must be null in JSON).\n"
        "  2           — set for CustVSR (model_color must be null in JSON).\n"
        "  For all RGB super-resolution models (SPAN, EDSR, etc.), keep 0."
    ),
    "out_precision_depth_derived": (
        "Derive output tensor precision from the input frame's bit depth.\n"
        "  Checked in ff_dnn_load_model_ivsr():\n"
        "    if (get_model_desc(ivsr_model)->out_precision_depth_derived) {\n"
        "        if (depth == 8)  strcpy(output_tensor_desc_set.precision, 'u8');\n"
        "        if (depth >= 10) strcpy(output_tensor_desc_set.precision, 'u16');\n"
        "    }\n"
        "  This overrides out_precision when true.\n"
        "  Used by EDSR which supports both 8-bit (u8 output) and 10/16-bit (u16)\n"
        "  via the same model weights, automatically selected at runtime.\n"
        "  false for almost all other models."
    ),
}


def print_deep_dive():
    """Print the complete parameter reference."""
    print("\n" + "=" * 78)
    print("iVSR JSON Config — Deep-dive parameter reference")
    print("=" * 78)
    for field, doc in PARAM_DOCS.items():
        print(f"\n  [{field}]")
        for line in doc.splitlines():
            print(f"    {line}")
    print()


# ─────────────────────────────────────────────────────────────────────────────
# Section 5: Main config generation
# ─────────────────────────────────────────────────────────────────────────────

def generate_config(
    xml_path: str,
    name_override: Optional[str],
    non_interactive: bool,
) -> Dict:
    # ── Parse IR ─────────────────────────────────────────────────────────────
    inputs, outputs = parse_ir(xml_path)

    if not inputs:
        print("ERROR: No Parameter (input) layers found in the IR XML.", file=sys.stderr)
        sys.exit(1)

    clues = scan_early_ops(xml_path)
    norm_op_type, norm_values = detect_input_normalization_constant(xml_path)
    norm_signal = classify_input_normalization(norm_op_type, norm_values)

    inp = inputs[0]
    out = outputs[0] if outputs else None

    in_shape = inp["shape"]
    in_et = inp["element_type"]
    in_name = inp["name"]

    out_shape = out["shape"] if out else []
    out_prec_raw = out["precision"] if out else "FP32"
    out_name = out["name"] if out else "output"

    # ── Auto-detect fields ────────────────────────────────────────────────────
    layout, _ = detect_layout(in_shape)
    nif, ch_per_frame = detect_nif(layout, in_shape)
    in_precision = map_element_type(in_et)
    out_precision = map_output_precision(out_prec_raw)

    # SR detection — compare spatial dims of input and output tensors
    scale_h, scale_w = 1, 1
    output_passthrough_dims = True  # default: assume passthrough
    if out_shape and in_shape:
        is_dyn_in = any(d <= 0 for d in in_shape[1:])
        is_dyn_out = any(d <= 0 for d in out_shape[1:])
        if not is_dyn_in and not is_dyn_out:
            scale_h, scale_w = detect_sr_scale(in_shape, out_shape)
            output_passthrough_dims = (scale_h <= 1 and scale_w <= 1)
        elif is_dyn_in and is_dyn_out:
            # Both dynamic — static shape comparison is impossible.
            # Try reading scale from the pixel_shuffle Reshape_1 literal dims.
            scale_h, scale_w = detect_scale_from_pixel_shuffle(xml_path)
            output_passthrough_dims = (scale_h <= 1 and scale_w <= 1)

    window_type, window_init_dup = infer_window_type(nif, layout)
    align = infer_align(nif, in_precision, layout)
    normalize_input, normalize_output = infer_normalize(in_precision, norm_signal)
    channel_divisor = detect_channel_divisor(layout, nif)

    # out_layout: for single-frame models, output layout = input layout.
    # For multi-frame batched (NFHWC input), output is typically NCHW or NHWC.
    if "NFHWC" in layout or "NFCHW" in layout:
        out_layout = "NCHW"
    else:
        out_layout = layout

    model_color: Optional[str] = "RGB" if ch_per_frame == 3 else None
    out_order = "RGB"
    out_precision_depth_derived = False
    # color_format_auto: 0 = use model_color string; 1 = VideoProc-auto; 2 = CustVSR-auto.
    # Only relevant when model_color is None; default 0 for all standard models.
    color_format_auto = 0

    model_name = name_override or Path(xml_path).stem

    # ── IR analysis output (always shown) ──────────────────────────────────
    print(f"\n{'='*68}")
    print(f"  IR Analysis: {xml_path}")
    print(f"{'='*68}")
    print(f"  Input tensors ({len(inputs)} found):")
    for i, inp_i in enumerate(inputs):
        print(f"    [{i}] name={inp_i['name']!r}  shape={inp_i['shape']}  "
              f"element_type={inp_i['element_type']!r}")
    print(f"  Output tensors ({len(outputs)} found):")
    for i, out_i in enumerate(outputs):
        print(f"    [{i}] name={out_i['name']!r}  shape={out_i['shape']}  "
              f"precision={out_i['precision']!r}")
    print()
    print(f"  Detected in_layout:           {layout}")
    print(f"  Detected nif:                 {nif}  (channels/frame: {ch_per_frame})")
    print(f"  Detected channel_divisor:     {channel_divisor}")
    print(f"  Detected in_precision:        {in_precision}")
    print(f"  Detected out_precision:       {out_precision}")
    if scale_h > 1 or scale_w > 1:
        print(f"  Detected SR scale:            {scale_h}×{scale_w} (height×width)")
    else:
        print(f"  Detected SR scale:            1×1 (passthrough or dynamic)")
    print(f"  Inferred output_passthrough:  {output_passthrough_dims}")
    print(f"  Inferred window_type:         {window_type}")
    print(f"  Inferred align:               {align}")
    if norm_signal == "raw_255_scale":
        vals_str = ", ".join(f"{v:.4g}" for v in norm_values)
        print(f"  Detected input constant:     {norm_op_type}({vals_str}) on the raw input")
        print(f"     → raw [0,255] scale baked into the graph itself")
        print(f"  Inferred normalize_input:     {normalize_input}  (confident)")
        print(f"  Inferred normalize_output:    {normalize_output}  (confident)")
    elif norm_signal == "meanstd_normalize":
        vals_str = ", ".join(f"{v:.4g}" for v in norm_values)
        print(f"  Detected input constant:     {norm_op_type}({vals_str}) on the raw input")
        print(f"     → mean/std-style normalization; only valid on already-[0,1] data")
        print(f"  Inferred normalize_input:     {normalize_input}  (confident)")
        print(f"  Inferred normalize_output:    {normalize_output}  (confident)")
    else:
        print(f"  Inferred normalize_input:     {normalize_input}  (no signal found — unconfirmed, verify below)")
        print(f"  Inferred normalize_output:    {normalize_output}  (no signal found — unconfirmed, verify below)")
    if clues["multi_input"]:
        print(f"\n  ⚠  Multiple Parameter layers detected ({len(inputs)}).")
        print(f"     Consider fusing conditioning inputs before export (see guide §3).")
    if clues["multi_output"]:
        print(f"\n  ⚠  Multiple Result layers detected ({len(outputs)}).")
        print(f"     The config will target the first output only.")
    if channel_divisor > 1:
        print(f"\n  ⚠  channel_divisor={channel_divisor}: {nif} frames are stacked on the")
        print(f"     channel axis ({layout}). Omitting channel_divisor from the JSON")
        print(f"     defaults to 1 in the C parser and reports the wrong channel count")
        print(f"     to FFmpeg (see patch 0005/parse_model_config_json).")
    print()
    # ── Interactive refinement (non-IR fields only) ───────────────────────
    if not non_interactive:
        print(f"\n{'─'*68}")
        print(f"  iVSR Config Generator — Interactive Refinement")
        print(f"  Model: {xml_path}")
        print(f"  Fields derived from the IR above are used as-is.")
        print(f"  Press Enter to accept the suggested value in [brackets].")
        print(f"{'─'*68}\n")

        model_name = _ask("name", model_name)
        align = _ask_int(
            "align  (0=none | 32/64/128 — heuristic, verify for new architectures)",
            align,
        )
        if channel_divisor > 1 or nif > 1:
            channel_divisor = _ask_int(
                "channel_divisor  (stacked frames on channel axis; nif frames / this = 3ch)",
                channel_divisor,
            )
        normalize_input = _ask_bool(
            "normalize_input  (divide uint8 by 255 before packing float32? True=[0,1] input)",
            normalize_input,
        )
        normalize_output = _ask_bool(
            "normalize_output  (multiply float32 output by 255? True=[0,1] output)",
            normalize_output,
        )
        mc_default = model_color or "null"
        mc_ans = _ask(
            "model_color  (training color space; RGB for all standard SR models)",
            mc_default,
            choices=["RGB", "I420_Three_Planes", "null"],
        )
        model_color = None if mc_ans == "null" else mc_ans

        out_order = _ask(
            "out_order  (output channel order)",
            out_order,
            choices=["RGB", "BGR", "NONE"],
        )

        _, wid_default = infer_window_type(nif, layout)
        window_type = _ask(
            "window_type  (frame queuing strategy; IR-inferred above)",
            window_type,
            choices=["single", "sliding", "in_queue"],
        )
        if window_type == "sliding":
            window_init_dup = _ask_bool(
                "window_init_dup  (duplicate first frame to prime the sliding window?)",
                wid_default,
            )
        else:
            window_init_dup = False
    # ── Build config dict ─────────────────────────────────────────────────────
    cfg: Dict[str, Any] = {
        "_comment_generated": (
            f"Auto-generated by generate_ivsr_model_config.py "
            f"from {Path(xml_path).name}"
        ),
        "_comment_input_tensor": (
            f"Input: name={in_name!r}  shape={in_shape}  element_type={in_et!r}"
        ),
        "_comment_output_tensor": (
            f"Output: name={out_name!r}  shape={out_shape}  precision={out_prec_raw!r}"
        ),
        "name": model_name,
        "nif": nif,
        "channel_divisor": channel_divisor,
        "align": align,
        "in_layout": layout,
        "in_precision": in_precision,
        "out_layout": out_layout,
        "out_precision": out_precision,
        "model_color": model_color,
        "out_order": out_order,
        "window_type": window_type,
        "window_init_dup": window_init_dup if window_type == "sliding" else False,
        "normalize_input": normalize_input,
        "normalize_output": normalize_output,
        "output_passthrough_dims": output_passthrough_dims,
        "out_precision_depth_derived": out_precision_depth_derived,
        "color_format_auto": color_format_auto,
    }

    return cfg


# ─────────────────────────────────────────────────────────────────────────────
# Section 6: Entry point
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="generate_ivsr_model_config.py",
        description=(
            "Auto-generate an iVSR JSON model config from an OpenVINO IR .xml file.\n"
            "Infers tensor layout, precision, nif, and window strategy from the IR;\n"
            "prompts interactively for the few fields that require domain knowledge."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap_dedent("""
Examples
--------
  # Interactive (recommended first use):
  python3 generate_ivsr_model_config.py models/span_x4.xml

  # Fully automatic (CI / scripted pipelines):
  python3 generate_ivsr_model_config.py models/rife.xml --non-interactive

  # Override output path and model name:
  python3 generate_ivsr_model_config.py model.xml -o configs/mymodel.json -n "MyModel"

  # Print the complete parameter reference (no IR file needed):
  python3 generate_ivsr_model_config.py --deep-dive

  # Validate the output against the JSON schema:
  jsonschema -i mymodel_config.json ivsr_model_config.schema.json
"""),
    )
    parser.add_argument(
        "xml",
        nargs="?",
        help="Path to the OpenVINO IR .xml file",
    )
    parser.add_argument(
        "--output", "-o",
        default=None,
        help="Output JSON path (default: <xml_stem>_config.json next to the xml)",
    )
    parser.add_argument(
        "--name", "-n",
        default=None,
        help="Model name override (default: derived from the xml filename)",
    )
    parser.add_argument(
        "--non-interactive",
        action="store_true",
        help="Suppress all prompts; use auto-detected defaults for every field",
    )
    parser.add_argument(
        "--deep-dive",
        action="store_true",
        help="Print the complete field-by-field parameter reference and exit",
    )

    args = parser.parse_args()

    if args.deep_dive:
        print_deep_dive()
        sys.exit(0)

    if not args.xml:
        parser.print_help()
        sys.exit(1)

    if not os.path.isfile(args.xml):
        print(f"ERROR: File not found: {args.xml}", file=sys.stderr)
        sys.exit(1)

    output_path = args.output
    if output_path is None:
        p = Path(args.xml)
        output_path = str(p.parent / (p.stem + "_config.json"))

    cfg = generate_config(
        xml_path=args.xml,
        name_override=args.name,
        non_interactive=args.non_interactive,
    )

    with open(output_path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")

    print(f"\nConfig written to: {output_path}")
    print("\n── Generated config ─────────────────────────────────────────────────")
    public = {k: v for k, v in cfg.items() if not k.startswith("_comment")}
    print(json.dumps(public, indent=2))
    print()
    print("── Next steps ──────────────────────────────────────────────────────")
    print(f"  1. Validate:  jsonschema -i {output_path} ivsr_model_config.schema.json")
    print(f"  2. Run:")
    xml_name = Path(args.xml).name.replace(".xml", "")
    print(f"       ./ffmpeg -i input.mp4 \\")
    print(f"         -vf \"format=rgb24,dnn_processing=dnn_backend=ivsr:\\")
    print(f"       model={args.xml}:input={cfg.get('_comment_input_tensor','input').split('name=')[1].split('  ')[0].strip(chr(39))}:output={cfg.get('_comment_output_tensor','output').split('name=')[1].split('  ')[0].strip(chr(39))}:\\")
    print(f"       model_type=-1:model_config={output_path}:device=GPU\" \\")
    print(f"         -pix_fmt yuv420p output.mp4")


def textwrap_dedent(s: str) -> str:
    """Minimal textwrap.dedent equivalent to avoid stdlib import."""
    lines = s.split("\n")
    # find minimum leading spaces on non-empty lines
    min_indent = None
    for line in lines:
        stripped = line.lstrip()
        if stripped:
            indent = len(line) - len(stripped)
            if min_indent is None or indent < min_indent:
                min_indent = indent
    if min_indent is None:
        return s
    return "\n".join(
        line[min_indent:] if len(line) >= min_indent else line for line in lines
    )


if __name__ == "__main__":
    main()
