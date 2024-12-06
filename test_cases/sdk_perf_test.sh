#!/bin/bash
gpu_precision=('f16' 'f32')
cpu_precision=('f32' 'bf16')
device=('CPU' 'GPU.0' 'MULTI:GPU.0,GPU.1')
resolution=('/home/media/djx/ivsr/data_model/cuc_quantization_dataset/mix/LR/120' '/home/media/djx/ivsr/data_model/cuc_quantization_dataset/mix/HR/120')
nframe=120

function benchmark_app_test()
{
    cd /workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/bin/intel64/Release
    d_array=(`echo $2 | tr '.:,' ' '`)
    p_array=(`echo $4 | tr '/' ' '`)
    device_name=${d_array[0]}
    resolu=${p_array[7]}
    echo "--------${1}_${device_name}_${3}_${resolu}_${5}.log--------"
    ./benchmark_app -m /home/media/djx/EDSR-PyTorch/src/ov_22_3_models/edsr.xml -d $2 -hint latency -infer_precision $3 > /home/media/djx/benchmark_test_log/${1}_${device_name}_${3}_1080_${5}_latency.log
    sleep 5
    ./benchmark_app -m /home/media/djx/EDSR-PyTorch/src/ov_22_3_models/edsr.xml -d $2 -hint throughput -infer_precision $3 > /home/media/djx/benchmark_test_log/${1}_${device_name}_${3}_1080_${5}_throughput.log
    sleep 5
}

function perf_test()
{
    cd /home/media/djx/ivsr_edsr_pr/ivsr_sdk/bin
    d_array=(`echo $2 | tr '.:,' ' '`)
    p_array=(`echo $4 | tr '/' ' '`)
    device_name=${d_array[0]}
    resolu=${p_array[7]}
    echo "--------${1}_${device_name}_${3}_${resolu}_${5}.log--------"
    ./vsr_sample --model_path=/home/media/djx/EDSR-PyTorch/src/ov_22_3_models/edsr.xml --data_path=$4 --nig=$nframe --device=$2  --normalize_factor=255.0 --precision=$3 > ./perf_test_log/${1}_${device_name}_${3}_${resolu}_${5}.log
    sleep 5

}

# --build OV enable oneDNN
cd /workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino
rm -r en_install
rm -r en_build
./enablednn_build.sh
source ./en_install/setupvars.sh
for d in ${device[@]}; do
    if [ "$d" == "CPU" ];
    then
        for p in ${cpu_precision[@]}; do
            for r in ${resolution[@]}; do
                perf_test dnnON $d $p $r sdk
                # benchmark_app_test dnnON $d $p $r benchmarkapp
            done
        done
    else
        for p in ${gpu_precision[@]}; do
            for r in ${resolution[@]}; do
                perf_test dnnON $d $p $r sdk
                # benchmark_app_test dnnON $d $p $r benchmarkapp
            done
        done
    fi
done

# --build OV disable oneDNN
cd /workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino
rm -r dis_install
rm -r dis_build
./disablednn_build.sh
source ./dis_install/setupvars.sh
cd /home/media/djx/ivsr_edsr_pr/ivsr_sdk/bin
for d in ${device[@]}; do
    if [ "$d" == "CPU" ];
    then
        for p in ${cpu_precision[@]}; do
            for r in ${resolution[@]}; do
                perf_test dnnOFF $d $p $r sdk
                # benchmark_app_test dnnOFF $d $p $r benchmarkapp
            done
        done
    else
        for p in ${gpu_precision[@]}; do
            for r in ${resolution[@]}; do
                perf_test dnnOFF $d $p $r sdk
                #benchmark_app_test dnnOFF $d $p $r benchmarkapp
            done
        done
    fi
done
