#!/bin/bash

# Parameters
test_path=$PWD
HEADERS=(
    "ffmpeg"
    "vsr_sample"
)
LOG_DIR=${test_path}/fuzzing_logs               # Directory for log files
ITERATIONS=20                      # Number of fuzzing iterations per command line
# Ensure radamsa and ffmpeg are installed
command -v radamsa >/dev/null 2>&1 || { echo "radamsa could not be found. Please install it." >&2; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg could not be found. Please install it." >&2; exit 1; }

# Create log directory if it doesn't exist
if [ -d ${LOG_DIR} ];then
    rm -rf ${LOG_DIR}/*
else
    mkdir ${LOG_DIR}
fi
nums=0
for TEST_TYPE in "${HEADERS[@]}"; do
    if [[ "$TEST_TYPE" == "ffmpeg" ]]; then
        CMD_FILE=${test_path}/ivsr_ffmpeg_cmds.txt        # File with sample ffmpeg command lines
        BIN_DIR=/workspace/ivsr/ivsr_ffmpeg_plugin/ffmpeg
        BASIC_HEAD="./ffmpeg"
    elif [[ "$TEST_TYPE"="vsr_sample" ]];then
        CMD_FILE=${test_path}/ivsr_sample_cmds.txt        # File with sample ffmpeg command lines
        BIN_DIR=/workspace/ivsr/ivsr_sdkout/bin
        BASIC_HEAD="./vsr_sample"
    fi
    # Start fuzzing command lines
    while IFS= read -r line; do
        for i in $(seq 1 $ITERATIONS); do
            # Generate the fuzzed command line
            fuzzed_line=$(echo "$line" | radamsa)
            # Log file name based on iteration
            log_file=${LOG_DIR}/fuzzing_test.log
            full_cmd="${BASIC_HEAD} ${fuzzed_line}"
            if [ "$fuzzed_line" = "$line" ]; then
                echo "!same cmd,continue"
                continue
            else
                nums=$((nums + 1))
                cd ${BIN_DIR}
                echo ${full_cmd} >> ${LOG_DIR}/fuzzing_test_cmds.txt
                echo "Fuzzing command ${nums} line:${full_cmd}" >> $log_file
                echo "---------------------------------------------------------------------------" >> $log_file
                ${full_cmd} >> $log_file 2>&1
                ec=$?
                echo "---------------------------------------------------------------------------" >> $log_file                
                # if [ "$ec" -ne 1 ] && [ "$ec" -ne 0 ] && [ "$ec" -ne 11 ]; then
                #     # echo "**SOMETHING HAS GONE AWRY!**"
                #     echo "!cur ec:${ec},cur num :${nums}"
                # fi
            fi
        done
    done < "$CMD_FILE"
done
echo "Command line fuzzing complete."