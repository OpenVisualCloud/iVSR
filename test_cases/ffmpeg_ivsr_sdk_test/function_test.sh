#!/bin/bash
MODEL_PATH=/workspace
BasicVSR_PATH=${MODEL_PATH}/0_iVSR_v0.1_models
EDSR_PATH=${MODEL_PATH}
CUSTOMER_PATH=${MODEL_PATH}/Meta_OV_models
FFMPEG_BIN_DIR=/workspace/ivsr/ivsr_ffmpeg_plugin/based_on_ivsr_sdk_backend/ffmpeg
TEST_SCRIPT_DIR=/workspace/ivsr/test_cases/ffmpeg_ivsr_sdk_test
OUT_MD5_FILE=/workspace/ivsr/test_cases/ffmpeg_ivsr_sdk_test/testvideo_model_output_md5.txt
TEST_MD5_FILE=/workspace/ivsr/test_cases/ffmpeg_ivsr_sdk_test/testvideo_input_md5.txt
resolutions_all=(
"720x1280"
"640x640"
"640x360"
"360x640"
"576x1024"
"540x960"
"1080x1920"
"1280x720"
"1080x1080"
"480x854"
"960x540"
"360x360"
"720x900"
"288x512"
"426x426"
"854x480"
"426x240"
"1080x1350"
"240x426"
"512x288"
"480x852"
"384x384"
"720x720"
"480x480"
"540x540"
"352x640"
"960x960"
"854x854"
"270x480"
"512x640"
"480x270"
"224x400"
"216x384"
"640x480"
"1920x1080"
"608x1080"
"480x848"
"400x500"
"900x1600"
"544x960"
"720x1282"
"720x960"
"256x256"
"384x216"
"960x720"
"640x352"
"1280x1280"
"852x480"
"480x640"
"340x426"
"358x640"
"320x400"
"256x144"
"400x400"
"512x512"
"1024x1280"
"144x256"
"406x720"
"1088x1920"
"576x576"
"384x480"
"718x1280"
"368x656"
"1200x1200"
"480x360"
"384x288"
"400x224"
"682x854"
"720x1270"
"362x640"
"426x320"
"864x1080"
"640x1138"
"720x1278"
"512x384"
"528x660"
"528x396"
"640x368"
"368x640"
"600x600"
"848x480"
"656x1166"
"234x426"
"680x1200"
"340x600"
"272x480"
"1600x900"
"1024x576"
"432x540"
"238x426"
"1440x1080"
"320x576"
"720x896"
"1000x1000"
"432x768"
"960x544"
"268x480"
"888x1578"
"220x400"
)

#BasicVSR model need to set extension and op_xml options
EXTENSION=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so
OP_XML=/workspace/ivsr/ivsr_ov/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml

LOG_DIR=${FFMPEG_BIN_DIR}/function_test_log
if [ -d ${LOG_DIR} ];then
    rm -rf ${LOG_DIR}/*
else
    mkdir ${LOG_DIR}
fi
# Generate 30 frames test video
generate_test_video(){
    cd ${FFMPEG_BIN_DIR}
    for resolution in "${resolutions_all[@]}"; do
        width=$(echo $resolution | cut -d'x' -f1)
        height=$(echo $resolution | cut -d'x' -f2)
        test_video_name=test_video_${width}x${height}_fn30.mp4
        ./ffmpeg -f lavfi -i testsrc=duration=1:size=${width}x${height}:rate=30 -c:v libx264 ${test_video_name} -y
        generated_video_md5=`md5sum ${test_video_name} | awk {'print $1'}`
        reference_md5=$(grep "^${test_video_name}:" ${TEST_MD5_FILE} | cut -d':' -f2)
        if [ ${generated_video_md5} = ${reference_md5} ];then
            echo "Generate test video successfully."
        else
            echo "Failed to generate test video."
            exit
        fi
    done

}

function_test()
{
    cd ${FFMPEG_BIN_DIR}
    model_name=$1
    model_type=$2
    device=$3
    rest_param="&"
    case ${model_name} in
    BasicVSR)
        if [ ${model_type} = "fp32" ];then
            model=${BasicVSR_PATH}/ov1_w_custom_fp32/basicvsr_x2_release_ov1_w_custom_fp32_3x1080x1920.xml
        else
            model=${BasicVSR_PATH}/ov1_w_custom_int8/basicvsr_x2_release_ov1_w_custom_int8_3x1080x1920.xml
        fi
        model_num=0
        nif=3
        normalize_factor=1.0
        format=bgr24
        resolution_list="1920x1080"
        rest_param="&extension=${EXTENSION}&op_xml=${OP_XML}&"
        ;;
    EDSR)
        model=${EDSR_PATH}/edsr.xml
        model_num=2
        nif=1
        normalize_factor=225.0
        format=bgr24
        resolution_list=("${resolutions_all[@]}")
        ;;
    CUSTOMER)
        model=${CUSTOMER_PATH}/meta_dynamic_04_15.xml
        model_num=3
        nif=1
        normalize_factor=1.0
        format=yuv420p
        resolution_list=("${resolutions_all[@]}")
        ;;
    *)
        echo "Unknown model name: $value"
        ;;
    esac

    for shape in "${resolution_list[@]}"; do
        width=$(echo $shape | cut -d'x' -f1)
        height=$(echo $shape | cut -d'x' -f2)
        test_video_name=test_video_${width}x${height}_fn30.mp4
        out_video_name=output_fn30_${model_name}_${device}_${model_type}_${width}x${height}.yuv
        command="./ffmpeg -i ${test_video_name} -pix_fmt yuv420p -y
                -vf format=${format},dnn_processing=dnn_backend=ivsr:model=${model}:input=input:output=output:nif=${nif}:backend_configs='nireq=1&device=${device}${rest_param}model_type=${model_num}&normalize_factor=${normalize_factor}' ${out_video_name}"
        start_time=`date +%s`
        detail_log_dir=${LOG_DIR}/function_test_${model_name}_${device}_${model_type}_${width}x${height}.log
        ${command} > ${detail_log_dir} 2>&1
        exit_status=$?
        if [ $exit_status -ne 0 ]; then
            echo "Command terminated with exit status $exit_status."
            echo "test_case: function_${model_name}_${model_type}_${device}_${width}x${height}, result: Fail, error_info: IVSR Command Run Error" >> ${LOG_DIR}/function_test_fail.log
        else
            end_time=`date +%s`
            duration=$[ $end_time - $start_time ]
            check_result ${model_name} ${model_type} ${device} ${duration} ${out_video_name} ${width} ${height}
        fi
    done

}

check_result()
{
    model_name=$1
    model_type=$2
    device=$3
    duration=$4
    out_video_name=$5
    width=$6
    height=$7
    test_md5=`md5sum ${out_video_name} | awk {'print $1'}`
    reference_md5=$(grep "^${out_video_name}:" ${OUT_MD5_FILE} | cut -d':' -f2)
    if [ ${test_md5} = ${reference_md5} ];then
        echo "test_case: function_${model_name}_${model_type}_${device}_${width}x${height}, duration: ${duration}s, result: Pass" >> ${LOG_DIR}/function_test_total.log
    else
        echo "test_case: function_${model_name}_${model_type}_${device}_${width}x${height}, duration: ${duration}s, result: Fail, error_info: MD5 Error" >> ${LOG_DIR}/function_test_total.log
        echo "test_case: function_${model_name}_${model_type}_${device}_${width}x${height}, duration: ${duration}s, result: Fail, error_info: MD5 Error" >> ${LOG_DIR}/function_test_fail.log
    fi

    if [ -f "${out_video_name}" ]; then
        rm ${out_video_name}
    fi
}

delete_testvideo()
{
    cd ${FFMPEG_BIN_DIR}
    for resolution in "${resolutions_all[@]}"; do
        width=$(echo $resolution | cut -d'x' -f1)
        height=$(echo $resolution | cut -d'x' -f2)
        test_video_name=test_video_${width}x${height}_fn30.mp4
        if [ -f "${test_video_name}" ]; then
            rm ${test_video_name}
        fi
    done
}

run()
{
    echo "Start Function Test"
    function_test BasicVSR fp32 CPU
    function_test BasicVSR fp32 GPU
    function_test BasicVSR int8 CPU
    function_test BasicVSR int8 GPU
    function_test EDSR fp32 CPU
    function_test EDSR fp32 GPU
    function_test CUSTOMER fp32 CPU
    delete_testvideo
    echo "Finish Function Test"

}

generate_test_video

run
