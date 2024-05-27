#!/bin/bash

#delete useless files
rm -rf ./ivsr_sdk/privates/model_guard
rm -rf ./ivsr_ov/based_on_openvino_2022.1
rm -rf ./ivsr_sdk/tools
rm -rf ./ivsr_sdk/ov2022.3.dockerfile
rm -rf ./ivsr_sdk/ov2023.2.dockerfile
rm -rf ./ivsr_sdk/build_docker.sh
rm -rf ./ivsr_ov/based_on_openvino_2022.3/Dockerfile
rm -rf ./ivsr_ov/based_on_openvino_2022.3/build_docker.sh
rm -rf ./ivsr_ov/README.md
rm -rf ./test_cases

#todo: add models:

#delete previous header & add new header
update_header_for_file() {
    local file="$1"
    local new_head=$(cat <<'EOF'
/********************************************************************************
* INTEL CONFIDENTIAL
* Copyright (C) 2023 Intel Corporation
*
* This software and the related documents are Intel copyrighted materials,
* and your use of them is governed by the express license under
* which they were provided to you ("License").Unless the License
* provides otherwise, you may not use, modify, copy, publish, distribute, disclose or
* transmit this software or the related documents without Intel's prior written permission.
*
* This software and the related documents are provided as is,
* with no express or implied warranties, other than those that are expressly stated in the License.
*******************************************************************************/
EOF
)
    first_non_comment_line=$(grep -n -m 1 -v '^//' "$file" | cut -d: -f1)
    last_comment_line=$((first_non_comment_line-1))

    if [ "$last_comment_line" -gt 0 ]; then
        sed -i "1,${last_comment_line}d" "$file"
    fi
    {
        echo "$new_head"
        cat "$file"
    } > "${file}_new" && mv "${file}_new" "$file"
}

export -f update_header_for_file

# Find all files ending with .hpp or .cpp and process them in update_header_for_file
find ./ivsr_sdk -type f \( -name "*.cpp" -o -name "*.hpp" \) -exec bash -c 'update_header_for_file "$0"' {} \;
# Comment out this line of ./ivsr_sdk/CMakeLists.txt because we deleted the ivsr_sdl/tools folder
sed -i '16s/^add_subdirectory(tools)/#&/' ./ivsr_sdk/CMakeLists.txt
#package files
tar -czvf ivsr_release_pkg.tar.gz  --exclude='./build_package.sh' --exclude='./.git' ./
