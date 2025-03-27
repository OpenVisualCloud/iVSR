/* Copyright (C) 2025 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

/**
 * @file engine.h
 * backend inference API,
 * it is the wrapper of backend inference API.
 */

#ifndef INFER_TASK_HPP
#define INFER_TASK_HPP

#include <memory>
#include <functional>
#include <string>
#include "ivsr.h"
#include "utils.hpp"

typedef enum {
    GPU = 0x0,   // GPU
    CPU = 0x1,   // CPU
    AUTO = 0x2,  // AUTO, will allow backend engine determined automatically
} InferFlag;

class InferTask {
public:
    using Ptr = std::shared_ptr<InferTask>;
    using QueueCallbackFunction = std::function<void(InferTask::Ptr)>;
    // construct function
    InferTask(char* inBuf, char* outBuf, QueueCallbackFunction callbackQueue, InferFlag flag, ivsr_cb_t* ivsr_cb)
        : _callbackFunction(callbackQueue),
          flag_(flag),
          inputPtr_(inBuf),
          outputPtr_(outBuf),
          cb(ivsr_cb) {}

    InferFlag getInferFlag() {
        return flag_;
    }

    double get_execution_time_in_milliseconds() const {
        auto execTime = std::chrono::duration_cast<ns>(_endTime - _startTime);
        return static_cast<double>(execTime.count()) * 0.000001;
    }

public:
    QueueCallbackFunction _callbackFunction;
    InferFlag flag_ = InferFlag::GPU;  // Default will use GPU to do inference task
    char* inputPtr_ = nullptr;         // input buffer ptr
    char* outputPtr_ = nullptr;        // output buffer pointer
    Time::time_point _startTime;
    Time::time_point _endTime;
    ivsr_cb_t* cb = nullptr;
};

#endif //INFER_TASK_HPP
