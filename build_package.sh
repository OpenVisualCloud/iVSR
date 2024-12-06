#!/bin/bash

RELEASE_VERSION="2024.05"

BASEDIR=$(pwd)

git clean -dfx

TEMP_DIR="/tmp/ivsr_release_${RELEASE_VERSION}"
# create release package
mkdir -p $TEMP_DIR

cp -rf * $TEMP_DIR

cd $TEMP_DIR

#delete useless files
rm -rf ./ivsr_sdk/privates/model_guard
rm -rf ./ivsr_ov/based_on_openvino_2022.1
rm -rf ./ivsr_sdk/tools
rm -rf ./ivsr_sdk/ov2022.3.dockerfile
rm -rf ./ivsr_sdk/ov2023.2.dockerfile
rm -rf ./ivsr_sdk/build_docker.sh
rm -rf ./ivsr_sdk/build.sh
rm -rf ./ivsr_sdk/test
rm -rf ./ivsr_ov/based_on_openvino_2022.3/Dockerfile
rm -rf ./ivsr_ov/based_on_openvino_2022.3/build_docker.sh
rm -rf ./ivsr_ov/based_on_openvino_2022.3/README.md
rm -rf ./ivsr_ov/README.md
rm -rf ./test_cases
rm -rf ./.clang-format
rm -rf ./.gitignore
rm -rf ./.gitmodules
rm -rf .git
rm build_package.sh

# Comment out this line of ./ivsr_sdk/CMakeLists.txt because we deleted the ivsr_sdl/tools folder
sed -i '17s/^add_subdirectory(tools)/#&/' ./ivsr_sdk/CMakeLists.txt

cd /tmp && tar -czvf ivsr_release_pkg_${RELEASE_VERSION}.tar.gz ivsr_release_${RELEASE_VERSION}
mv ivsr_release_pkg_${RELEASE_VERSION}.tar.gz $BASEDIR
rm -rf $TEMP_DIR
