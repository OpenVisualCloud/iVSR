#!/bin/bash
echo "Attention! Make sure the following paths are legal and appropriate to use."
echo "Command line example: ./ov3_metric_test.sh <output-path> <libcustom_extension.so path> <flow_warp.xml-path> <vsr_sample or basicvsr_sample>"

model_dir="/mnt/test_data/Share/TrainingData/vpp/trained_models/0_iVSR_v0.5_models"
models=("ov3_models_fp32/basicvsr_x2_opensource_release_custom_op_1_3_3_1080_1920.xml" \
    "ov3_models_fp32/basicvsr_x2_opensource_release_custom_op_1_3_3_360_640.xml" \
    "ov3_models_int8/optimized_acc_aware_basicvsr_x2_opensource_release_custom_op_1_3_3_1080_1920_000.xml" \
    "ov3_models_int8/optimized_acc_aware_basicvsr_x2_opensource_release_custom_op_1_3_3_1080_1920_000_ignored.xml")
nif=3
data_dir="/mnt/test_data/Share/TrainingData/vpp/cuc_videos_for_NRE_M2/quantization_dataset"
sub_folders=("mix/LR/120")
validate_folders=("mix/HR/120")
extension=$2  #$2= xxx/xx/libcustom_extension.so
path_to_cldnn_config=$3  # $3=xx/flow_warp.xml
save_dir=$1
devices=("CPU" "GPU" "MULTI:GPU.0,GPU.1")

# log name format
FILENAME="metric_"$(date '+%Y-%m-%d-%H-%M').log
{
    echo "-------------------- " $4 " -- metric inference -------------------------"
    for device in ${devices[*]}
    do
        dev_multi=$(echo $device | grep "MULTI")

        for m in ${models[*]}
        do
            mtt=${m%%/*}
            res_360=$(echo $m | grep "360")
            res_1080=$(echo $m | grep "1080")
            if [[ "$res_360" != "" ]]
            then 
                mtt=$mtt"_360"
            elif [[ "$res_1080" != "" ]]
            then
                mtt=$mtt"_1080"
            fi

            is_ignored=$(echo $m | grep "ignored")
            if [[ "$is_ignored" != "" ]]
            then
                mtt=$mtt"_ignored"
            fi

            # multi-gpu only for 360P model
            if [[ "$dev_multi" != "" ]] && [[ "$res_360" == "" ]]
            then
                continue
            fi

            for data_folder in ${sub_folders[*]}
            do 
                data_path="$data_dir/$data_folder"
                model_path="$model_dir/$m"
                dff=${data_folder%%/*}
                save_path="$save_dir/$device/$mtt/$dff"
                if [ ! -d $save_path ];then
                    mkdir -p $save_path
                fi
                nig=$(ls -l ${data_path} | grep "^-" | wc -l)
                nig=$((nig/3))

                if [ $4 == "vsr_sample" ];then
                    echo "---------Device: "$device" --- Model:"$m" --- Data:"$data_folder" --- NIg:"$nig"--------"
                    ./vsr_sample --data_path=$data_path --model_path=$model_path --device=$device --extension=$extension --cldnn_config=$path_to_cldnn_config --save_predictions --save_path=$save_path --nig=$nig
                elif [ $4 == "basicvsr_sample" ];then
                    echo "---------Device: "$device" --- Model:"$m" --- Data:"$data_folder" --- NIF:"$nif"--------"
                    ./basicvsr_sample --data_path=$data_path --model_path=$model_path --device=$device --extension=$extension --cldnn_config=$path_to_cldnn_config --save_path=$save_path --nif=$nif
                else
                    echo "Please select vsr_sample inference or basicvsr_sample inference."
                fi

                echo "------ metric quality -------"
                val_path=$data_dir/$validate_folders
                python3 metric_evaluate.py --test_data_path $save_path --ref_data_path $val_path --simple_process
            done        
        done
    done

} 2>&1 | tee $FILENAME

echo "Save log file: $FILENAME"
