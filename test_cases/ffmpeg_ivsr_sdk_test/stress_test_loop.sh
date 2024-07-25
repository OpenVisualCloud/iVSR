#!/bin/bash
json_file="test_params.json"
if [[ ! -f "$json_file" ]]; then
  echo "$json_file does not exist!"
  exit 1
fi

json_data=$(cat "$json_file")
test_case=$(echo "$json_data" | jq -r '.test_cases')
BasicVSR_FP32_PATH=$(echo "$json_data" | jq -r '.pathes.BasicVSR_FP32_PATH')
EDSR_FP32_PATH=$(echo "$json_data" | jq -r '.pathes.EDSR_FP32_PATH')
EDSR_FP16_PATH=$(echo "$json_data" | jq -r '.pathes.EDSR_FP16_PATH')
CUSTOMER_FP32_PATH=$(echo "$json_data" | jq -r '.pathes.CUSTOMER_FP32_PATH')
TSENET_FP16_PATH=$(echo "$json_data" | jq -r '.pathes.TSENET_FP16_PATH')
SVP_FP32_PATH=$(echo "$json_data" | jq -r '.pathes.SVP_FP32_PATH')
SVP_INT8_PATH=$(echo "$json_data" | jq -r '.pathes.SVP_INT8_PATH')
SVP_FP16_PATH=$(echo "$json_data" | jq -r '.pathes.SVP_FP16_PATH')
SVP_SE_FP16_PATH=$(echo "$json_data" | jq -r '.pathes.SVP_SE_FP16_PATH')
FFMPEG_BIN_DIR=$(echo "$json_data" | jq -r '.pathes.FFMPEG_BIN_DIR')

LOOP=100
H=1080
W=1920

TEST_VIDEO_NAME=test_video_${W}x${H}_fn30.mp4
TEST_VIDEO_MD5=4262395c1dec9b7f3edd1f7911b11527

LOG_DIR=${FFMPEG_BIN_DIR}/stress_test_loop_log
if [ -d ${LOG_DIR} ];then
    rm -rf ${LOG_DIR}/*
else
    mkdir ${LOG_DIR}
fi
#BasicVSR model need to set extension and op_xml options
EXTENSION=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so
OP_XML=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml

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
    ./ffmpeg -f lavfi -i testsrc=duration=1:size=${W}x${H}:rate=30 -c:v libx264 ${TEST_VIDEO_NAME} -y
    generated_video_md5=`md5sum ${TEST_VIDEO_NAME} | awk {'print $1'}`
    if [ ${generated_video_md5} = ${TEST_VIDEO_MD5} ];then
        echo "Generate test video successfully."
    else
        echo "Failed to generate test video."
        exit
    fi
}

stress_loop_test()
{
    cd ${FFMPEG_BIN_DIR}
    model_name=$1
    model_type=$2
    device=$3
    rest_param="&"
    case ${model_name} in
    BasicVSR)
        if [ ${model_type} = "fp32" ];then
            model=${BasicVSR_FP32_PATH}
        else
            echo "Unknown BasicVSR model type: $model_type"
        fi
        model_num=0
        nif=3
        normalize_factor=1.0
        format=bgr24
        rest_param="&extension=${EXTENSION}&op_xml=${OP_XML}&"
        ;;
    EDSR)
        if [ ${model_type} = "fp32" ];then
            model=${EDSR_FP32_PATH}
        elif [ ${model_type} = "fp16" ];then
            model=${EDSR_FP16_PATH}
        else
            echo "Unknown EDSR model type: $model_type"
        fi
        model_num=2
        nif=1
        normalize_factor=255.0
        format=bgr24
        ;;
    CUSTOMER)
        if [ ${model_type} = "fp32" ];then
            model=${CUSTOMER_FP32_PATH}
        fi
        model_num=3
        nif=1
        normalize_factor=1.0
        format=yuv420p
        ;;
    TSENET)
        if [ ${model_type} = "fp16" ];then
            model=${TSENET_FP16_PATH}
        else
            echo "Unknown TSENET model type: $model_type"
        fi
        model_num=4
        nif=1
        normalize_factor=1.0
        format=bgr24
        ;;
    SVP)
        if [ ${model_type} = "fp32" ];then
            model=${SVP_FP32_PATH}
        elif [ ${model_type} = "fp16" ];then
            model=${SVP_FP16_PATH}
        else
            model=${SVP_INT8_PATH}
        fi
        model_num=1
        nif=1
        normalize_factor=1.0
        format=bgr24
        ;;
    SVP_SE)
        if [ ${model_type} = "fp16" ];then
            model=${SVP_SE_FP16_PATH}
        else
            echo "Unknown SVP-SE model type: $model_type"
        fi
        model_num=1
        nif=1
        normalize_factor=1.0
        format=bgr24
        ;;
    *)
        echo "Unknown model name: $value"
        ;;
    esac
    log_dir=${LOG_DIR}/log_${model_name}_${model_type}_${device}
    if [ -d ${log_dir} ];then
        rm -rf ${log_dir}/*
    else
        mkdir ${log_dir}
    fi
    test_out_name="loop_test_${model_name}_${device}_${model_type}_${W}x${H}.mp4"
    command="./ffmpeg -i ${TEST_VIDEO_NAME} -y
            -vf format=${format},dnn_processing=dnn_backend=ivsr:model=${model}:input=input:output=output:nif=${nif}:backend_configs='nireq=1&device=${device}${rest_param}model_type=${model_num}&normalize_factor=${normalize_factor}' ${test_out_name}"
    end_time=`date +%s`

    start_time=`date +%s`
    echo "------ Test ${model_name} ${model_type} model on ${device} ------"
    for i in $(seq $LOOP)
    do
        echo "=== $i/$LOOP (${model_type} ${device}) ==="
        ${command} > ${log_dir}/loop_${i}.log
    done
    end_time=`date +%s`
    duration=$[ $end_time - $start_time ]
    log_cnt=`ls ${log_dir} | wc -l`

    if [ ${log_cnt} = ${LOOP} ];then
        echo "test_case: stress_loop_${model_name}_${device}_${model_type}_${W}x${H}, duration: ${duration}s, result: Pass" >> ${LOG_DIR}/stress_test_loop_total.log
    else
        echo "test_case: stress_loop_${model_name}_${device}_${model_type}_${W}x${H}, duration: ${duration}s, result: Fail, error_info: Not enough loop numbers" >> ${LOG_DIR}/stress_test_loop_total.log
        echo "test_case: stress_loop_${model_name}_${device}_${model_type}_${W}x${H}, duration: ${duration}s, result: Fail, error_info: Not enough loop numbers" >> ${LOG_DIR}/stress_test_loop_fail.log
    fi
    if [ -f "${test_out_name}" ]; then
        rm ${test_out_name}
    fi
}

delete_testvideo()
{
    if [ -f "${TEST_VIDEO_NAME}" ]; then
        rm ${TEST_VIDEO_NAME}
    fi
}

run()
{
    echo "Start Streess Test(Loop)"
    test_models=$(echo "$json_data" | jq -r '.test_models[]')
    devices=$(echo "$json_data" | jq -r '.devices[]')
    for cur_model in ${test_models}; do
        for cur_device in ${devices}; do
            case ${cur_model} in
            BasicVSR)
                stress_loop_test BasicVSR fp32 ${cur_device}
                ;;
            EDSR)
                stress_loop_test EDSR fp32 ${cur_device}
                stress_loop_test EDSR fp16 ${cur_device}
                ;;
            CUSTOMER)
                if [ "$cur_device" = "GPU" ]; then
                    echo "CUSTOMER model doesn't support GPU yet."
                else
                    stress_loop_test CUSTOMER fp32 ${cur_device}
                fi
                ;;
            TSENET)
                # if [ "$cur_device" = "GPU" ]; then
                #     echo "CUSTOMER model doesn't support GPU yet."
                # else
                #     stress_loop_test TSENET fp16 ${cur_device}
                # fi
                ;;
            SVP)
                stress_loop_test SVP fp32 ${cur_device}
                stress_loop_test SVP fp16 ${cur_device}
                stress_loop_test SVP int8 ${cur_device}
                ;;
            SVP_SE)
                stress_loop_test SVP_SE fp16 ${cur_device}
                ;;
            *)
                echo "Unknown test model name: $cur_model"
                ;;
            esac
        done
    done
    delete_testvideo
    echo "Finish Streess Test(Loop)"
}

generate_test_video

run
