#!/bin/bash

# Move perf_test.sh to the folder where executable file benchmark_app exits
# ./perf_test.sh <log file prefix> 
if [[ $# -eq 0 ]] ;then
   echo 'Error: Please set log file prefix!'
   echo 'Usage: Move vsr_sdk_perf_test.sh to where vsr_sample exists!'
   echo 'Usage: ./ov3_vsr_sdk_perf_test.sh <log file prefix> <extension.so-path> <cldnn config-path>'
   exit 0
fi

# log name format
FILENAME=$1_$(date '+%Y-%m-%d-%H-%M').log


test_perf(){
    echo "****************CPU 1080P->4k****************"
    echo "Fixed core"
    echo "-- FP32 Model: 1080P --- CPU --- w/ custom op"
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[0]} --device=CPU --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- CPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[1]} --device=CPU --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- CPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[2]} --device=CPU --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[3]} --device=CPU --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
 
    echo "No specified core"
    echo "-- FP32 Model: 1080P --- CPU --- w/ custom op"
    ./vsr_sample --model_path=${models_path}/${models[0]} --device=CPU --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- CPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[1]} --device=CPU --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- CPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[2]} --device=CPU --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- CPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[3]} --device=CPU --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1

    echo "****************CPU 4k->8k****************"
    echo "Fixed core"
    echo "-- FP32 Model: 1080P --- CPU --- w/ custom op"
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[0]} --device=CPU --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- CPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[1]} --device=CPU --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- CPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[2]} --device=CPU --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- CPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[3]} --device=CPU --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1

    echo "No specified core"
    echo "-- FP32 Model: 1080P --- CPU --- w/ custom op"
    ./vsr_sample --model_path=${models_path}/${models[0]} --device=CPU --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- CPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[1]} --device=CPU --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- CPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[2]} --device=CPU --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- CPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[3]} --device=CPU --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1

    echo "****************GPU.0 1080P->4k****************"
    echo "Fixed core"
    echo "-- FP32 Model: 1080P --- GPU --- w/ custom op"
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[0]} --device=GPU.0 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[1]} --device=GPU.0 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[2]} --device=GPU.0 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[3]} --device=GPU.0 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1

    echo "No specified core"
    echo "-- FP32 Model: 1080P --- GPU --- w/ custom op"
    ./vsr_sample --model_path=${models_path}/${models[0]} --device=GPU.0 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[1]} --device=GPU.0 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[2]} --device=GPU.0 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[3]} --device=GPU.0 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1

    echo "****************GPU.0 4k->8k****************"
    echo "Fixed core"
    echo "-- FP32 Model: 1080P --- GPU --- w/ custom op"
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[0]} --device=GPU.0 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[1]} --device=GPU.0 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[2]} --device=GPU.0 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[3]} --device=GPU.0 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1

    echo "No specified core"
    echo "-- FP32 Model: 1080P --- GPU --- w/ custom op"
    ./vsr_sample --model_path=${models_path}/${models[0]} --device=GPU.0 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[1]} --device=GPU.0 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[2]} --device=GPU.0 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[3]} --device=GPU.0 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1

    echo "****************Multi-GPU 1080P->4k****************"
    echo "Fixed core"
    echo "-- FP32 Model: 360P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[1]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "No specified core"
    echo "-- FP32 Model: 360P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[1]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_LR --extension=$so_path --cldnn_config=$flow_warp --nig=1

    echo "****************MULTI-GPU 4k->8k****************"
    echo "Fixed core"
    echo "-- FP32 Model: 1080P --- GPU --- w/ custom op"
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[0]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[1]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[2]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- GPU --- w/ custom op "
    taskset -c 1 ./vsr_sample --model_path=${models_path}/${models[3]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1

    echo "No specified core"
    echo "-- FP32 Model: 1080P --- GPU --- w/ custom op"
    ./vsr_sample --model_path=${models_path}/${models[0]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- FP32 Model: 360P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[1]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Model: 1080P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[2]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1
    echo "-- INT8 Ignored Model: 1080P --- GPU --- w/ custom op "
    ./vsr_sample --model_path=${models_path}/${models[3]} --device=MULTI:GPU.0,GPU.1 --data_path=$test_data_HR --extension=$so_path --cldnn_config=$flow_warp --nig=1

}

{
    models_path="/home/media/yang/model/0_iVSR_v0.5_models"
    so_path="./libcustom_extension.so"
    flow_warp="../../../flow_warp_cl_kernel/flow_warp.xml"
    models=("ov3_models_fp32/basicvsr_x2_opensource_release_custom_op_1_3_3_1080_1920.xml" \
        "ov3_models_fp32/basicvsr_x2_opensource_release_custom_op_1_3_3_360_640.xml" \
	"ov3_models_int8/optimized_acc_aware_basicvsr_x2_opensource_release_custom_op_1_3_3_1080_1920_000.xml" \
        "ov3_models_int8/optimized_acc_aware_basicvsr_x2_opensource_release_custom_op_1_3_3_1080_1920_000_ignored.xml")
    test_data_LR="/mnt/test_data/Share/TrainingData/vpp/cuc_videos_for_NRE_M2/quantization_dataset/mix/LR/120"
    test_data_HR="/mnt/test_data/Share/TrainingData/vpp/cuc_videos_for_NRE_M2/quantization_dataset/mix/HR/120"
    test_perf $models_path $models $test_data_LR $test_data_HR $so_path $flow_warp

} 2>&1 | tee $FILENAME

echo "Save log file: $FILENAME"
