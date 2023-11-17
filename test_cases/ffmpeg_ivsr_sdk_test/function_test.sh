#!/bin/bash
MODEL_PATH=/workspace/0_iVSR_v0.1_models
FFMPEG_BIN_DIR=/workspace/ivsr/ivsr_ffmpeg_plugin/based_on_ivsr_sdk_backend/ffmpeg
TEST_VIDEO_NAME=test_video_1080p_fn30.mp4
TEST_VIDEO_MD5=6fdd9bcfc86db585b5ff9525e162c0c2

REFERENCE_output_fn30_CPU_fp32=fad9dfb2d12262e76ade4280e2f4aabe
REFERENCE_output_fn30_CPU_int8=ef007cffb255a71c578f3263fcc890f6
REFERENCE_output_fn30_GPU_fp32=6ff5adf02f53b4a175fba6cfd601c541
REFERENCE_output_fn30_GPU_int8=af4da8991755105833f92f20147146fc

# Generate 30 frames test video
generate_test_video(){
    cd ${FFMPEG_BIN_DIR}
    ./ffmpeg -f lavfi -i testsrc=duration=1:size=1920x1080:rate=30 -c:v libx264 ${TEST_VIDEO_NAME} -y
    generated_video_md5=`md5sum test_video_1080p_fn30.mp4 | awk {'print $1'}`
    if [ ${generated_video_md5} = ${TEST_VIDEO_MD5} ];then
        echo "Generate test video successfully."
    else
        echo "Failed to generate test video."
        exit
    fi
}

function_test()
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
    log_dir="function_test_log"
    if [ ! -d ${log_dir} ];then
        mkdir ${log_dir}
    fi

    command="./ffmpeg -i ${TEST_VIDEO_NAME} -y 
            -vf dnn_processing=dnn_backend=ivsr:model=${model}:input=input:output=output:nif=3:backend_configs='nireq=1&device=${device}' output_fn30_${device}_${model_type}.mp4" 
    
    start_time=`date +%s`
    ${command} > ${log_dir}/function_test_${device}_${model_type}.log
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
    test_md5=`md5sum output_fn30_${device}_${model_type}.mp4 | awk {'print $1'}`
    if [ ${test_md5} = ${reference_md5} ];then
        echo "test_case: function_${device}_${model_type}, duration: ${duration}s, result: Pass"
    else
        echo "test_case: function_${device}_${model_type}, duration: ${duration}s, result: Fail, error_info: MD5 Error"
    fi
}


run()
{
    echo "Start Function Test"
    function_test fp32 CPU ${REFERENCE_output_fn30_CPU_fp32}
    function_test fp32 GPU ${REFERENCE_output_fn30_GPU_fp32}
    function_test int8 CPU ${REFERENCE_output_fn30_CPU_int8}
    function_test int8 GPU ${REFERENCE_output_fn30_GPU_int8}
    echo "Finish Function Test"

}

generate_test_video

run