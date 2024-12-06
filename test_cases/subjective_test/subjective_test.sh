#!/bin/bash
MODEL_PATH=/workspace
BasicVSR_PATH=${MODEL_PATH}/0_iVSR_v0.1_models/dynamic_models
EDSR_PATH=${MODEL_PATH}
CUSTOMER_PATH=${MODEL_PATH}/Meta_OV_models
SVP_BASIC_PATH=${MODEL_PATH}/SVP_BASIC
SVP_SE_PATH=${MODEL_PATH}/SVP_SE
FFMPEG_BIN_DIR=/workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
videolist=/home/svp_test_videos/
video_out_path=/home/svp_test_out/
#BasicVSR model need to set extension and op_xml options
EXTENSION=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so
OP_XML=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml

LOG_DIR=${FFMPEG_BIN_DIR}/subjective_test_log
if [ -d ${LOG_DIR} ];then
    rm -rf ${LOG_DIR}/*
else
    mkdir ${LOG_DIR}
fi

subjective_test()
{
    cd ${FFMPEG_BIN_DIR}
    model_name=$1
    model_type=$2
    device=$3
    rest_param="&"
    echo "!!!!!!${model_name}"
    case ${model_name} in
    BasicVSR)
        # if [ ${model_type} = "fp32" ];then
        #     model=${BasicVSR_PATH}/ov1_w_custom_fp32/basicvsr_x2_release_ov1_w_custom_fp32_3x1080x1920.xml
        # else
        #     model=${BasicVSR_PATH}/ov1_w_custom_int8/basicvsr_x2_release_ov1_w_custom_int8_3x1080x1920.xml
        # fi
        model=${BasicVSR_PATH}/0_BasicVSR_release_models/basicvsr_x2_opensource_release_dynamic.xml
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
    SVP_BASIC)
        if [ ${model_type} = "fp32" ];then
            model=${SVP_BASIC_PATH}/FP32/dunet.xml
        elif [ ${model_type} = "fp16" ];then
            model=${SVP_BASIC_PATH}/FP16/dunet.xml
        else
            model=${SVP_BASIC_PATH}/INT8-performance/dunet.xml
        fi
        model_num=1
        nif=1
        normalize_factor=1.0
        format=bgr24

        ;;
    SVP_SE)
        if [ ${model_type} = "fp16" ];then
            model=${SVP_SE_PATH}/fp16-dynamic-shape/qnet3m_16165.xml
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
    for test_video_name in "$videolist"/*; do
        video_name=$(basename "$test_video_name")
        base_name="${video_name%.*}"
        out_video_name=${video_out_path}/${base_name}_${model_name}_${device}_${model_type}_qp0.mp4
        command="./ffmpeg -i ${test_video_name} -y 
                -vf format=${format},dnn_processing=dnn_backend=ivsr:model=${model}:input=input:output=output:nif=${nif}:backend_configs='nireq=1&device=${device}${rest_param}model_type=${model_num}&normalize_factor=${normalize_factor}' -c:v libx264 -preset ultrafast -qp 0 ${out_video_name}"

        echo ${command}
        start_time=`date +%s`
        detail_log_dir=${LOG_DIR}/${base_name}_${model_name}_${device}_${model_type}.log
        ${command} > ${detail_log_dir} 2>&1
        exit_status=$?

        if [ $exit_status -ne 0 ]; then
            echo "Command terminated with exit status $exit_status."
            echo "test_case:${base_name}_${model_name}_${model_type}_${device}, result: Fail, error_info: IVSR Command Run Error" >> ${LOG_DIR}/subjective_test_fail.log
        else
            end_time=`date +%s`
            duration=$[ $end_time - $start_time ]
            echo "test_case:${base_name}_${model_name}_${model_type}_${device}, result: Success" >> ${LOG_DIR}/subjective_test_success.log
        fi

    done

}

run()
{
    echo "Start Subjective Test"
    subjective_test SVP_SE fp16 GPU
    subjective_test SVP_SE fp16 CPU
    echo "Finish Subjective Test"

}

run
 