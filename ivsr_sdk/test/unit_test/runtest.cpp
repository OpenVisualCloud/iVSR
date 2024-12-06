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
#include <system_error>
#include <vector>
#include <gtest/gtest.h>
#include <random>
#include "../../include/ivsr.h"

template <typename T>
using uniformDistribution = typename std::conditional<
    std::is_floating_point<T>::value,
    std::uniform_real_distribution<T>,
    typename std::conditional<std::is_integral<T>::value, std::uniform_int_distribution<T>, void>::type>::type;

#include <chrono>
#include <ctime>
#include <mutex>

typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::nanoseconds ns;
std::mutex _mutex;
int count = 0;
struct callback_args{
    int flag;
    int nif;
    Time::time_point time;
    callback_args() {
        flag = 0;
        nif  = 0;
        time = Time::now();
    }
    callback_args(int f, int nif, Time::time_point t):flag(f),nif(nif),time(t){}
};

void completion_callback (void *args)
{
    std::cout << "unit test callback called" << std::endl;
    callback_args * cb_args = (callback_args*)args;
    cb_args->flag = 1;

    {
        std::lock_guard<std::mutex> lock(_mutex);
        count += 1;
    }

}

#define COMMON_SETUP                                                   \
    do {                                                               \
        config = new ivsr_config_t();                                  \
        config->key = IVSRConfigKey::INPUT_MODEL;                      \
        config->value = "./test_with_custom_op.xml";                   \
        config->next = nullptr;                                        \
        config_device= new ivsr_config_t();                            \
        config_device->key = IVSRConfigKey::TARGET_DEVICE;             \
        config_device->value = "CPU";                                  \
        config_device->next = nullptr;                                 \
        config->next = config_device;                                  \
        config_res= new ivsr_config_t();                               \
        config_res->key = IVSRConfigKey::INPUT_RES;                    \
        config_res->value = "1920,1080";                               \
        config_res->next = nullptr;                                    \
        config_device->next = config_res;                              \
    } while (0)                                                        \

#define COMMON_UNINIT                                                  \
    do {                                                               \
        delete config;                                                 \
        delete config_device;                                          \
        delete config_res;                                             \
    } while (0)                                                        \

TEST(VSR_Unit_Test, ValidInputTestForInit_CPU_withCustom)
{
    ivsr_handle handle = nullptr;
    ivsr_config_t *config = nullptr, *config_device = nullptr, *config_res = nullptr;
    COMMON_SETUP;

    ivsr_config_t *config_customlib = nullptr;
    config_customlib= (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_customlib->next = nullptr;
    config_customlib->key = IVSRConfigKey::CUSTOM_LIB;
    config_customlib->value = "./libcustom_extension.so";
    config_res->next = config_customlib;

    auto res = ivsr_init(config, &handle);
    EXPECT_EQ(IVSRStatus::OK, res) << "ValidInputTestForInit_CPU_withCustom test failed-init";
    res = ivsr_deinit(handle);
    EXPECT_EQ(IVSRStatus::OK, res) << "ValidInputTestForInit_CPU_withCustom test failed-deinit";
    free(config_customlib);
    COMMON_UNINIT;
    handle = nullptr;
}

TEST(VSR_Unit_Test, ValidInputTestForInit_GPU_withCustom)
{
    ivsr_handle handle = nullptr;
    ivsr_config_t *config = nullptr, *config_device = nullptr, *config_res = nullptr;
    COMMON_SETUP;

    ivsr_config_t *config_customlib = nullptr, *config_cldnn = nullptr;
    config_device->value = "GPU";

    config_customlib= (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_customlib->next = nullptr;
    config_customlib->key = IVSRConfigKey::CUSTOM_LIB;
    config_customlib->value = "./libcustom_extension.so";
    config_res->next = config_customlib;

    config_cldnn= (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_cldnn->next = nullptr;
    config_cldnn->key = IVSRConfigKey::CLDNN_CONFIG;
    config_cldnn->value = "./flow_warp.xml";
    config_customlib->next = config_cldnn;

    auto res = ivsr_init(config, &handle);
    EXPECT_EQ(IVSRStatus::OK, res) << "ValidInputTestForInit_GPU_withCustom test failed-init";
    res = ivsr_deinit(handle);
    EXPECT_EQ(IVSRStatus::OK, res) << "ValidInputTestForInit_GPU_withCustom test failed-deinit";
    free(config_customlib);
    free(config_cldnn);
    COMMON_UNINIT;
    handle = nullptr;
}

TEST(VSR_Unit_Test, ValidInputTestForInit_MultiGPU_withCustom)
{
    ivsr_handle handle = nullptr;
    ivsr_config_t *config = nullptr, *config_device = nullptr, *config_res = nullptr;
    COMMON_SETUP;

    ivsr_config_t *config_customlib = nullptr, *config_cldnn = nullptr;
    config_device->value = "MULTI:GPU.0,GPU.1";

    config_customlib= (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_customlib->next = nullptr;
    config_customlib->key = IVSRConfigKey::CUSTOM_LIB;
    config_customlib->value = "./libcustom_extension.so";
    config_res->next = config_customlib;

    config_cldnn= (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_cldnn->next = nullptr;
    config_cldnn->key = IVSRConfigKey::CLDNN_CONFIG;
    config_cldnn->value = "./flow_warp.xml";
    config_customlib->next = config_cldnn;

    auto res = ivsr_init(config, &handle);
    EXPECT_EQ(IVSRStatus::OK, res) << "ValidInputTestForInit_MultiGPU_withCustom test failed-init";
    res = ivsr_deinit(handle);
    EXPECT_EQ(IVSRStatus::OK, res) << "ValidInputTestForInit_MultiGPU_withCustom test failed-deinit";
    free(config_customlib);
    free(config_cldnn);
    COMMON_UNINIT;
    handle = nullptr;
}


TEST(VSR_Unit_Test, ValidInputTestForProcess_CPU_withCustom)
{
    ivsr_handle handle = nullptr;
    ivsr_config_t *config = nullptr, *config_device = nullptr, *config_res = nullptr;
    COMMON_SETUP;

    ivsr_config_t *config_customlib = nullptr;
    config_customlib= (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_customlib->key = IVSRConfigKey::CUSTOM_LIB;
    config_customlib->value = "./libcustom_extension.so";
    config_customlib->next = nullptr;
    config_res->next = config_customlib;

    auto res = ivsr_init(config, &handle);
    assert(res == IVSRStatus::OK);

    // ivsr process input and output
    int input_size[] = { 1, 3, 3, 1080, 1920 };
    size_t input_tensor_size = input_size[0] * input_size[1] * input_size[2] * input_size[3] * input_size[4];
    auto input_buffer = (float*)malloc( input_tensor_size * sizeof(float));

    size_t output_tensor_size = input_size[0] * input_size[1] * input_size[2] * input_size[3] * 2 * input_size[4] * 2;
    auto output_buffer = (float*)malloc( output_tensor_size * sizeof(float));

    // -prepare radom input data
    std::mt19937 gen(0);
    uniformDistribution<float> distribution(0, 255);
    for (size_t i = 0; i < input_tensor_size; i++) {
        input_buffer[i] = static_cast<float>(distribution(gen));
    }

    ivsr_cb_t cb;
    auto startTime = Time::now();
    callback_args cb_args(0,3,startTime);
    cb.ivsr_cb = completion_callback;
    cb.args = (void*)(&cb_args);
    count = 0;

    res = ivsr_process(handle, (char*)input_buffer, (char*)output_buffer, &cb);
    EXPECT_EQ(IVSRStatus::OK, res) << "ValidInputTestForProcess_CPU_withCustom test failed";
    
    while (count != 1) {
        usleep(100);
    }

    // free and deinit
    free(input_buffer);
    free(output_buffer);
    ivsr_deinit(handle);
    free(config_customlib);
    COMMON_UNINIT;
    handle = nullptr;
}

TEST(VSR_Unit_Test, ValidInputTestForProcess_GPU_withCustom)
{
    ivsr_handle handle = nullptr;
    ivsr_config_t *config = nullptr, *config_device = nullptr, *config_res = nullptr;
    COMMON_SETUP;

    ivsr_config_t *config_customlib = nullptr, *config_cldnn = nullptr;
    config_device->value = "GPU";

    config_customlib = (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_customlib->key = IVSRConfigKey::CUSTOM_LIB;
    config_customlib->value = "./libcustom_extension.so";
    config_customlib->next = nullptr;
    config_res->next = config_customlib;

    config_cldnn = (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_cldnn->key = IVSRConfigKey::CLDNN_CONFIG;
    config_cldnn->value = "./flow_warp.xml";
    config_cldnn->next = nullptr;
    config_customlib->next = config_cldnn;

    auto res = ivsr_init(config, &handle);
    assert(res == IVSRStatus::OK);

    // ivsr process input and output
    int input_size[] = { 1, 3, 3, 1080, 1920 };
    size_t input_tensor_size = input_size[0] * input_size[1] * input_size[2] * input_size[3] * input_size[4];
    auto input_buffer = (float*)malloc( input_tensor_size * sizeof(float));

    size_t output_tensor_size = input_size[0] * input_size[1] * input_size[2] * input_size[3] * 2 * input_size[4] * 2;
    auto output_buffer = (float*)malloc( output_tensor_size * sizeof(float));

    // -prepare radom input data
    std::mt19937 gen(0);
    uniformDistribution<float> distribution(0, 255);
    for (size_t i = 0; i < input_tensor_size; i++) {
        input_buffer[i] = static_cast<float>(distribution(gen));
    }

    ivsr_cb_t cb;
    auto startTime = Time::now();
    callback_args cb_args(0,3,startTime);
    cb.ivsr_cb = completion_callback;
    cb.args = (void*)(&cb_args);
    count = 0;

    res = ivsr_process(handle, (char*)input_buffer, (char*)output_buffer, &cb);
    EXPECT_EQ(IVSRStatus::OK, res) << "ValidInputTestForProcess_GPU_withCustom test failed";
    
    //wait for the completion callback
    while (count != 1) {
        usleep(100);
    }
    // free and deinit
    free(input_buffer);
    free(output_buffer);
    ivsr_deinit(handle);
    free(config_customlib);
    free(config_cldnn);
    COMMON_UNINIT;
    handle = nullptr;
}

TEST(VSR_Unit_Test, ValidInputTestForProcess_MultiGPU_withCustom)
{
    ivsr_handle handle = nullptr;
    ivsr_config_t *config = nullptr, *config_device = nullptr, *config_res = nullptr;
    COMMON_SETUP;

    ivsr_config_t *config_customlib = nullptr, *config_cldnn = nullptr;
    config_device->value = "MULTI:GPU.0,GPU.1";

    config_customlib = (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_customlib->key = IVSRConfigKey::CUSTOM_LIB;
    config_customlib->value = "./libcustom_extension.so";
    config_customlib->next = nullptr;
    config_res->next = config_customlib;

    config_cldnn = (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_cldnn->key = IVSRConfigKey::CLDNN_CONFIG;
    config_cldnn->value = "./flow_warp.xml";
    config_cldnn->next = nullptr;
    config_customlib->next = config_cldnn;

    auto res = ivsr_init(config, &handle);
    assert(res == IVSRStatus::OK);

    // ivsr process input and output
    int input_size[] = { 1, 3, 3, 1080, 1920 };
    size_t input_tensor_size = input_size[0] * input_size[1] * input_size[2] * input_size[3] * input_size[4];
    auto input_buffer = (float*)malloc( input_tensor_size * sizeof(float));

    size_t output_tensor_size = input_size[0] * input_size[1] * input_size[2] * input_size[3] * 2 * input_size[4] * 2;
    auto output_buffer = (float*)malloc( output_tensor_size * sizeof(float));

    // -prepare radom input data
    std::mt19937 gen(0);
    uniformDistribution<float> distribution(0, 255);
    for (size_t i = 0; i < input_tensor_size; i++) {
        input_buffer[i] = static_cast<float>(distribution(gen));
    }

    ivsr_cb_t cb;
    auto startTime = Time::now();
    callback_args cb_args(0,3,startTime);
    cb.ivsr_cb = completion_callback;
    cb.args = (void*)(&cb_args);
    count = 0;

    res = ivsr_process(handle, (char*)input_buffer, (char*)output_buffer, &cb);
    EXPECT_EQ(IVSRStatus::OK, res) << "ValidInputTestForProcess_MultiGPU_withCustom test failed";
    
    while (count != 1) {
        usleep(100);
    }

    // free and deinit
    free(input_buffer);
    free(output_buffer);
    ivsr_deinit(handle);
    free(config_customlib);
    free(config_cldnn);
    COMMON_UNINIT;
    handle = nullptr;
}

