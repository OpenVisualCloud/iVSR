#!/bin/bash
MODEL_PATH=/workspace/0_iVSR_v0.1_models
FFMPEG_BIN_DIR=/workspace/ivsr/ivsr_ffmpeg_plugin/based_on_ivsr_sdk_backend/ffmpeg
TEST_VIDEO_NAME=test_video_1080p_fn7500.mp4
TEST_VIDEO_MD5=27349a543eb891a0be7d8e1d49277531


REFERENCE_output_fn7500_CPU_fp32=d8709de35615d7883a3a8931937df230
REFERENCE_output_fn7500_CPU_int8=1b49f19c5807b42c07abee6df3873d50
REFERENCE_output_fn7500_GPU_fp32=aab52cc0fba1ae26934c530427105eaf
REFERENCE_output_fn7500_GPU_int8=9979bbb9abc71a65dc393d3ec2dd1fac


# Generate 7500 frames test video
generate_test_video(){
    cd ${FFMPEG_BIN_DIR}
    ./ffmpeg -f lavfi -i testsrc=duration=250:size=1920x1080:rate=30 -c:v libx264 ${TEST_VIDEO_NAME} -y
    generated_video_md5=`md5sum test_video_1080p_fn7500.mp4 | awk {'print $1'}`
    if [ ${generated_video_md5} = ${TEST_VIDEO_MD5} ];then
        echo "Generate test video successfully."
    else
        echo "Failed to generate test video."
        exit
    fi
}

stress_test()
{
    cd ${FFMPEG_BIN_DIR}
    model_type=$1
    device=$2
    reference_md5=$3
    if [ ${model_type} = "fp32" ];then
        model=${MODEL_PATH}/ov1_w_custom_fp32/basicvsr_x2_release_ov1_w_custom_fp32_3x1080x1920.xml
    else
        model=${MODEL_PATH}/ov1_w_custom_int8/basicvsr_x2_release_ov1_w_custom_int8_3x1080x1920.xml
    fi
    log_dir="stress_test_long_log"
    if [ ! -d ${log_dir} ];then
        mkdir ${log_dir}
    fi

    command="./ffmpeg -i ${TEST_VIDEO_NAME} -y 
            -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=${model}:input=input:output=output:nif=3:backend_configs='nireq=1&device=${device}' output_fn7500_${device}_${model_type}.mp4"
    
    start_time=`date +%s`
    ${command} > ${log_dir}/stress_test_long_${device}_${model_type}.log
    end_time=`date +%s`
    
    duration=$[ $end_time - $start_time ]

    check_result ${model_type} ${device} ${reference_md5} ${duration}

}

check_result()
{
    model_type=$1
    device=$2
    reference_md5=$3
    duration=$4
    test_md5=`md5sum output_fn7500_${device}_${model_type}.mp4 | awk {'print $1'}`
    if [ ${test_md5} = ${reference_md5} ];then
        echo "test_case: stress_long_${device}_${model_type}, duration: ${duration}s, result: Pass"
    else
        echo "test_case: stress_long_${device}_${model_type}, duration: ${duration}s, result: Fail, error_info: MD5 Error"
    fi
}


run()
{
    echo "Start Function Test"
    stress_test fp32 CPU ${REFERENCE_output_fn7500_CPU_fp32}
    stress_test fp32 GPU ${REFERENCE_output_fn7500_GPU_fp32}
    stress_test int8 CPU ${REFERENCE_output_fn7500_CPU_int8}
    stress_test int8 GPU ${REFERENCE_output_fn7500_GPU_int8}
    echo "Finish Function Test"

}

generate_test_video

run
