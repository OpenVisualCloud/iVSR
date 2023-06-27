#Copyright (C) 2023 Intel Corporation

cmake_minimum_required(VERSION 3.10)

project(IVSR DESCRIPTION "Intel Video Super Resolution SDK")

set(OUTPUT_FOLDER ${CMAKE_CURRENT_SOURCE_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${OUTPUT_FOLDER})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${OUTPUT_FOLDER})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${OUTPUT_FOLDER})
add_subdirectory(src)
add_subdirectory(samples)

if(ENABLE_TEST)
    add_subdirectory(test)
endif()
