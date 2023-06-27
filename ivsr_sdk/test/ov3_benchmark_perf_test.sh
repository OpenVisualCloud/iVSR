#!/bin/bash

# Move perf_test.sh to the folder where executable file benchmark_app exits
# ./perf_test.sh <log file prefix> 
if [[ $# -eq 0 ]] ;then
    echo 'Note: Only for reference!'
    echo 'Error: Please set log file prefix!'
    echo 'Usage: Move perf_test.sh to where benchmark_app exists!'
    echo 'Usage: ./ov3_benchmark_perf_test.sh <log file prefix>'
    exit 0
fi

# log name format
FILENAME=$1_$(date '+%Y-%m-%d-%H-%M').log


test_perf(){
    echo "*********************Fixed on one core ****************************"
    echo "***************Mode: Throughput*****************"
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P f32"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint throughput -infer_precision f32 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P bf16"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint throughput -infer_precision bf16 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P f32"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint throughput -infer_precision f32 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P bf16"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint throughput -infer_precision bf16 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- CPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[2]} -d CPU -hint throughput -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- CPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[3]} -d CPU -hint throughput -extensions $so_path -c $flow_warp

    echo "-- FP32 Model --- GPU --- w/ custom op 1080P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d GPU.0 -hint throughput -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- GPU --- w/ custom op 360P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d GPU.0 -hint throughput -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[2]} -d GPU.0 -hint throughput -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[3]} -d GPU.0 -hint throughput -extensions $so_path -c $flow_warp

    echo "-- FP32 Model --- GPU --- w/ custom op 1080P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d GPU.0 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- GPU --- w/ custom op 360P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d GPU.0 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[2]} -d GPU.0 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[3]} -d GPU.0 -hint none -nstreams 1 -extensions $so_path -c $flow_warp

    echo "*****************Mode: nstreams 1, nireq 1, nthreads 1********************"
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P f32"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint none -infer_precision f32 -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P bf16"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint none -infer_precision bf16 -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P f32"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint none -infer_precision f32 -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P bf16"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint none -infer_precision bf16 -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- CPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[2]} -d CPU -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- CPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[3]} -d CPU -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp

    echo "-- FP32 Model --- GPU --- w/ custom op 1080P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d GPU.0 -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- GPU --- w/ custom op 360P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d GPU.0 -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[2]} -d GPU.0 -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[3]} -d GPU.0 -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp

    echo "*****************Mode: latency********************"
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P f32"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint latency -infer_precision f32 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P bf16"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint latency -infer_precision bf16 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P f32"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint latency -infer_precision f32 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P bf16"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint latency -infer_precision bf16 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- CPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[2]} -d CPU -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- CPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[3]} -d CPU -hint latency -extensions $so_path -c $flow_warp

    echo "-- FP32 Model --- GPU --- w/ custom op 1080P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d GPU.0 -hint latency -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- GPU --- w/ custom op 360P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d GPU.0 -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[2]} -d GPU.0 -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[3]} -d GPU.0 -hint latency -extensions $so_path -c $flow_warp

    echo "*********************No specified core ****************************"
    echo "***************Mode: Throughput*****************"
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P f32"
    ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint throughput -infer_precision f32 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P bf16"
    ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint throughput -infer_precision bf16 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P f32"
    ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint throughput -infer_precision f32 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P bf16"
    ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint throughput -infer_precision bf16 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- CPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[2]} -d CPU -hint throughput -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- CPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[3]} -d CPU -hint throughput -extensions $so_path -c $flow_warp

    echo "-- FP32 Model --- GPU --- w/ custom op 1080P"
    ./benchmark_app -m ${models_path}/${models[0]} -d GPU.0 -hint throughput -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- GPU --- w/ custom op 360P"
    ./benchmark_app -m ${models_path}/${models[1]} -d GPU.0 -hint throughput -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[2]} -d GPU.0 -hint throughput -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[3]} -d GPU.0 -hint throughput -extensions $so_path -c $flow_warp

    echo "-- FP32 Model --- GPU --- w/ custom op 1080P"
    ./benchmark_app -m ${models_path}/${models[0]} -d GPU.0 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- GPU --- w/ custom op 360P"
    ./benchmark_app -m ${models_path}/${models[1]} -d GPU.0 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[2]} -d GPU.0 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[3]} -d GPU.0 -hint none -nstreams 1 -extensions $so_path -c $flow_warp

    echo "*****************Mode: nstreams 1, nireq 1, nthreads 1********************"
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P f32"
    ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint none -infer_precision f32 -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P bf16"
    ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint none -infer_precision bf16 -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P f32"
    ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint none -infer_precision f32 -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P bf16"
    ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint none -infer_precision bf16 -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- CPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[2]} -d CPU -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- CPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[3]} -d CPU -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp

    echo "-- FP32 Model --- GPU --- w/ custom op 1080P"
    ./benchmark_app -m ${models_path}/${models[0]} -d GPU.0 -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- GPU --- w/ custom op 360P"
    ./benchmark_app -m ${models_path}/${models[1]} -d GPU.0 -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[2]} -d GPU.0 -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[3]} -d GPU.0 -hint none -nstreams 1 -nireq 1 -nthreads 1 -extensions $so_path -c $flow_warp

    echo "*****************Mode: latency********************"
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P f32"
    ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint latency -infer_precision f32 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 1080P bf16"
    ./benchmark_app -m ${models_path}/${models[0]} -d CPU -hint latency -infer_precision bf16 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P f32"
    ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint latency -infer_precision f32 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- CPU --- w/ custom op 360P bf16"
    ./benchmark_app -m ${models_path}/${models[1]} -d CPU -hint latency -infer_precision bf16 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- CPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[2]} -d CPU -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- CPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[3]} -d CPU -hint latency -extensions $so_path -c $flow_warp

    echo "-- FP32 Model --- GPU --- w/ custom op 1080P"
    ./benchmark_app -m ${models_path}/${models[0]} -d GPU.0 -hint latency -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- GPU --- w/ custom op 360P"
    ./benchmark_app -m ${models_path}/${models[1]} -d GPU.0 -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[2]} -d GPU.0 -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[3]} -d GPU.0 -hint latency -extensions $so_path -c $flow_warp

    echo "************Multi-GPU*****************"
    echo "*****************Fixed one core************"
    echo "********Mode: Latency*****************"
    echo "-- FP32 Model --- Multi-GPU --- w/ custom op 1080P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d MULTI:GPU.0,GPU.1 -hint latency -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- Multi-GPU --- w/ custom op 360P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d MULTI:GPU.0,GPU.1 -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- Multi-GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[2]} -d MULTI:GPU.0,GPU.1 -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- Multi-GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[3]} -d MULTI:GPU.0,GPU.1 -hint latency -extensions $so_path -c $flow_warp

    echo "********Mode: nstreams 1*****************"
    echo "-- FP32 Model --- Multi-GPU --- w/ custom op 1080P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[0]} -d MULTI:GPU.0,GPU.1 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- Multi-GPU --- w/ custom op 360P"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[1]} -d MULTI:GPU.0,GPU.1 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- Multi-GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[2]} -d MULTI:GPU.0,GPU.1 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- Multi-GPU --- w/ custom op"
    taskset -c 1 ./benchmark_app -m ${models_path}/${models[3]} -d MULTI:GPU.0,GPU.1 -hint none -nstreams 1 -extensions $so_path -c $flow_warp

    echo "***************No specified core*************"
    echo "********Mode: nstreams 1*****************"
    echo "-- FP32 Model --- Multi-GPU --- w/ custom op 1080P"
    ./benchmark_app -m ${models_path}/${models[0]} -d MULTI:GPU.0,GPU.1 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- Multi-GPU --- w/ custom op 360P"
    ./benchmark_app -m ${models_path}/${models[1]} -d MULTI:GPU.0,GPU.1 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- Multi-GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[2]} -d MULTI:GPU.0,GPU.1 -hint none -nstreams 1 -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- Multi-GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[3]} -d MULTI:GPU.0,GPU.1 -hint none -nstreams 1 -extensions $so_path -c $flow_warp

    echo "********Mode: Latency*****************"
    echo "-- FP32 Model --- Multi-GPU --- w/ custom op 1080P"
    ./benchmark_app -m ${models_path}/${models[0]} -d MULTI:GPU.0,GPU.1 -hint latency -extensions $so_path -c $flow_warp
    echo "-- FP32 Model --- Multi-GPU --- w/ custom op 360P"
    ./benchmark_app -m ${models_path}/${models[1]} -d MULTI:GPU.0,GPU.1 -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model --- Multi-GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[2]} -d MULTI:GPU.0,GPU.1 -hint latency -extensions $so_path -c $flow_warp
    echo "-- INT8 Model IGONRE --- Multi-GPU --- w/ custom op"
    ./benchmark_app -m ${models_path}/${models[3]} -d MULTI:GPU.0,GPU.1 -hint latency -extensions $so_path -c $flow_warp
}

{
    models_path="/home/media/yang/0_iVSR_v0.5_models"
    so_path="./libcustom_extension.so"
    flow_warp="../../../flow_warp_cl_kernel/flow_warp.xml"
    models=("ov3_models_fp32/basicvsr_x2_opensource_release_custom_op_1_3_3_1080_1920.xml" \
	"ov3_models_fp32/basicvsr_x2_opensource_release_custom_op_1_3_3_360_640.xml" \
        "ov3_models_int8/optimized_acc_aware_basicvsr_x2_opensource_release_custom_op_1_3_3_1080_1920_000.xml" \
        "ov3_models_int8/optimized_acc_aware_basicvsr_x2_opensource_release_custom_op_1_3_3_1080_1920_000_ignored.xml")

    test_perf $models_path $models $so_path $flow_warp

} 2>&1 | tee $FILENAME

echo "Save log file: $FILENAME"
