# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: AI TECHNOLOGY EVALUATION LICENSE
#
cmake_minimum_required(VERSION 3.10)
set (TARGET_NAME "vsr_unit_test")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}/lib)
include(FetchContent)
FetchContent_Declare(
  googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG v1.14.0
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/googletest
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "Disable gtest installation" FORCE)
FetchContent_MakeAvailable(googletest)
file(GLOB_RECURSE SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/unit_test/*.cpp)
file(GLOB_RECURSE HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/../../include/*.h)
set(INCLUDE_DIR ${INCLUDE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/../../include)
enable_testing()

add_executable(${TARGET_NAME} ${HEADERS} ${SOURCES})
target_link_libraries(${TARGET_NAME} GTest::gtest_main)
target_link_libraries(${TARGET_NAME} ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libivsr.so)

include(GoogleTest)
gtest_discover_tests(${TARGET_NAME})
message("VSR Unit Test finished compile")

