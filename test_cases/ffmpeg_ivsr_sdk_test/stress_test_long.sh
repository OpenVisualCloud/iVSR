#!/bin/bash
MODEL_PATH=/workspace
BasicVSR_PATH=${MODEL_PATH}/0_iVSR_v0.1_models/dynamic_models
EDSR_PATH=${MODEL_PATH}
CUSTOMER_PATH=${MODEL_PATH}/Meta_OV_models
FFMPEG_BIN_DIR=/workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
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

stress_test()
{
    cd ${FFMPEG_BIN_DIR}
    model_name=$1
    model_type=$2
    device=$3
    rest_param="&"
    case ${model_name} in
    BasicVSR)
        if [ ${model_type} = "fp32" ];then
            model=${BasicVSR_PATH}/fp32/basicvsr_x2_opensource_release_dynamic.xml
        fi
        model_num=0
        nif=3
        normalize_factor=1.0
        format=bgr24
        rest_param="&extension=${EXTENSION}&op_xml=${OP_XML}&"
        ;;
    EDSR)
        model=${EDSR_PATH}/edsr.xml
        model_num=2
        nif=1
        normalize_factor=255.0
        format=bgr24
        ;;
    CUSTOMER)
        model=${CUSTOMER_PATH}/meta_dynamic_04_15.xml
        model_num=3
        nif=1
        normalize_factor=1.0
        format=yuv420p
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
        echo "test_case: stress_long_${model_name}_${model_type}_${device}_${width}x${height},result: Fail, error_info: IVSR Command Run Error" >> ${LOG_DIR}/stress_test_long_fail.log
        echo "test_case: stress_long_${model_name}_${model_type}_${device}_${width}x${height},result: Fail, error_info: IVSR Command Run Error" >> ${LOG_DIR}/stress_test_loop_total.log
    else
        end_time=`date +%s`
        duration=$[ $end_time - $start_time ]
        echo "test_case: stress_long_${model_name}_${model_type}_${device}_${width}x${height}, duration: ${duration}s, result: Pass" >> ${LOG_DIR}/stress_test_long_total.log
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
    stress_test BasicVSR fp32 CPU
    stress_test BasicVSR fp32 GPU
    # stress_test BasicVSR int8 CPU
    # stress_test BasicVSR int8 GPU
    stress_test EDSR fp32 CPU
    stress_test EDSR fp32 GPU
    stress_test CUSTOMER fp32 CPU
    delete_testvideo
    echo "Finish Streess Test(Long)"

}

generate_test_video

run
