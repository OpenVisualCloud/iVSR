#!/bin/bash -ex

pack=0
while [[ $# -gt 0 ]];
do
    case "$1" in
        "--pack")
            pack=1
            shift
            ;;
        *)
            echo "Wrong parameter!"
            exit 1
            ;;
    esac
done

ROOT_DIR="$(realpath "$(pwd)/..")"

if [ ! -d "./build" ];then
        mkdir -p ./build
fi
cd ./build
cmake .. \
 -DENABLE_LOG=OFF -DENABLE_PERF=OFF -DENABLE_TEST=ON \
 -DCMAKE_BUILD_TYPE=Release
make

echo "Building vsr finished."

