#!/bin/bash
LOOP=100
MODEL_PATH=/workspace/0_iVSR_v0.1_models
FFMPEG_BIN_DIR=/workspace/ivsr/ivsr_ffmpeg_plugin/based_on_ivsr_sdk_backend/ffmpeg
TEST_VIDEO_NAME=test_video_1080p_fn30.mp4
TEST_VIDEO_MD5=6fdd9bcfc86db585b5ff9525e162c0c2

function usage()
{
cat << EOF

Usage: $0 [options]
Options:
    echo "  --help                      Print this message."
    echo "  --loop <num>                Loop number."
EOF
}

while [[ $# -gt 0 ]];
do
    case "$1" in
        "--loop")
            LOOP=$2
            echo "Loop number is ${LOOP}"
            shift
            ;;
        "-h"|"--help")
            usage
            exit 0
            ;;
        *)
            echo "unknown option '$1', use --help"
            exit 1
    esac
    shift
done

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

stress_loop_test()
{
    model_type=$1
    device=$2
    if [ ${model_type} = "fp32" ];then
        model=${MODEL_PATH}/ov1_w_custom_fp32/basicvsr_x2_release_ov1_w_custom_fp32_3x1080x1920.xml
    else
        model=${MODEL_PATH}/ov1_w_custom_int8/basicvsr_x2_release_ov1_w_custom_int8_3x1080x1920.xml
    fi
    log_dir="log_${model_type}_${device}"
    if [ -d ${log_dir} ];then
        rm -rf ${log_dir}/*
    else
        mkdir ${log_dir}
    fi

    command="./ffmpeg -i ${TEST_VIDEO_NAME} -y 
            -vf format=bgr24,dnn_processing=dnn_backend=ivsr:model=${model}:input=input:output=output:nif=3:backend_configs='nireq=1&device=${device}' test_out.mp4"
    end_time=`date +%s`
    
    start_time=`date +%s`
    echo "------ Test ${model_type} model on ${device} ------"
    for i in $(seq $LOOP)
    do
        echo "=== $i/$LOOP (${model_type} ${device}) ==="
        ${command} > ${log_dir}/loop_${i}.log
    done
    end_time=`date +%s`
    duration=$[ $end_time - $start_time ]
    log_cnt=`ls ${log_dir} | wc -l`

    if [ ${log_cnt} = ${LOOP} ];then
        echo "test_case: stress_loop_${device}_${model_type}, duration: ${duration}s, result: Pass"
    else
        echo "test_case: stress_loop_${device}_${model_type}, duration: ${duration}s, result: Fail, error_info: Not enough loop numbers"
    fi
}


run()
{
    echo "Start Streess Test(Loop)"
    stress_loop_test fp32 CPU
    stress_loop_test fp32 GPU
    stress_loop_test int8 CPU
    stress_loop_test int8 GPU
    echo "Finish Streess Test(Loop)"
}

generate_test_video

run
