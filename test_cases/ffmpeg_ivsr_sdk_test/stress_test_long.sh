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

H=1080
W=1920

TEST_VIDEO_NAME=test_video_${W}x${H}_fn7500.mp4
TEST_VIDEO_MD5=1a1ff42e37bc53d57f2f81f278eabc59

LOG_DIR=${FFMPEG_BIN_DIR}/stress_test_long_log
if [ -d ${LOG_DIR} ];then
    rm -rf ${LOG_DIR}/*
else
    mkdir ${LOG_DIR}
fi
#BasicVSR model need to set extension and op_xml options
EXTENSION=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so
OP_XML=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml

# Generate 7500 frames test video
generate_test_video(){
    cd ${FFMPEG_BIN_DIR}
    ./ffmpeg -f lavfi -i testsrc=duration=250:size=${W}x${H}:rate=30 -c:v libx264 ${TEST_VIDEO_NAME} -y
    generated_video_md5=`md5sum ${TEST_VIDEO_NAME} | awk {'print $1'}`
    if [ ${generated_video_md5} = ${TEST_VIDEO_MD5} ];then
        echo "Generate test video successfully."
    else
        echo "Failed to generate test video."
        exit
    fi
}

stress_long_test()
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
    out_video_name="output_fn7500_${model_name}_${device}_${model_type}_${W}x${H}.mp4"
    command="./ffmpeg -i ${TEST_VIDEO_NAME} -y
            -vf format=${format},dnn_processing=dnn_backend=ivsr:model=${model}:input=input:output=output:nif=${nif}:backend_configs='nireq=1&device=${device}${rest_param}model_type=${model_num}&normalize_factor=${normalize_factor}' ${out_video_name}"
    start_time=`date +%s`
    ${command} > ${LOG_DIR}/stress_test_long_${model_name}_${device}_${model_type}.log
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "Command terminated with exit status $exit_status."
        echo "test_case: stress_long_${model_name}_${model_type}_${device}_${W}x${H},result: Fail, error_info: IVSR Command Run Error" >> ${LOG_DIR}/stress_test_long_fail.log
        echo "test_case: stress_long_${model_name}_${model_type}_${device}_${W}x${H},result: Fail, error_info: IVSR Command Run Error" >> ${LOG_DIR}/stress_test_loop_total.log
    else
        end_time=`date +%s`
        duration=$[ $end_time - $start_time ]
        echo "test_case: stress_long_${model_name}_${model_type}_${device}_${W}x${H}, duration: ${duration}s, result: Pass" >> ${LOG_DIR}/stress_test_long_total.log
    fi
    if [ -f "${out_video_name}" ]; then
        rm ${out_video_name}
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
    echo "Start Streess Test(Long)"
    test_models=$(echo "$json_data" | jq -r '.test_models[]')
    devices=$(echo "$json_data" | jq -r '.devices[]')
    for cur_model in ${test_models}; do
        for cur_device in ${devices}; do
            case ${cur_model} in
            BasicVSR)
                stress_long_test BasicVSR fp32 ${cur_device}
                ;;
            EDSR)
                stress_long_test EDSR fp32 ${cur_device}
                stress_long_test EDSR fp16 ${cur_device}
                ;;
            CUSTOMER)
                if [ "$cur_device" = "GPU" ]; then
                    echo "CUSTOMER model doesn't support GPU yet."
                else
                    stress_long_test CUSTOMER fp32 ${cur_device}
                fi
                ;;
            TSENET)
                # if [ "$cur_device" = "GPU" ]; then
                #     echo "CUSTOMER model doesn't support GPU yet."
                # else
                #     stress_long_test TSENET fp16 ${cur_device}
                # fi
                ;;
            SVP)
                stress_long_test SVP fp32 ${cur_device}
                stress_long_test SVP fp16 ${cur_device}
                stress_long_test SVP int8 ${cur_device}
                ;;
            SVP_SE)
                stress_long_test SVP_SE fp16 ${cur_device}
                ;;
            *)
                echo "Unknown test model name: $cur_model"
                ;;
            esac
        done
    done
    delete_testvideo
    echo "Finish Streess Test(Long)"

}

generate_test_video

run
