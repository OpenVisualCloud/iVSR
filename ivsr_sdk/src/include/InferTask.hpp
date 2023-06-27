// Copyright (C) 2022-2023 Intel Corporation

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
    GPU = 0x0, //GPU
    CPU = 0x1, //CPU
    AUTO = 0x2, //AUTO, will allow backend engine determined automatically
} InferFlag;

typedef std::function<void()> QueueCallbackFunction;

class InferTask {
public:
    using Ptr = std::shared_ptr<InferTask>;
    //construct function
    InferTask(char* inBuf, char* outBuf,  QueueCallbackFunction callbackQueue, InferFlag flag):
        inputPtr_(inBuf), outputPtr_(outBuf), _callbackQueue(callbackQueue), flag_(flag) {}

    InferFlag getInferFlag() { return flag_; }

    double get_execution_time_in_milliseconds() const {
        auto execTime = std::chrono::duration_cast<ns>(_endTime - _startTime);
        return static_cast<double>(execTime.count()) * 0.000001;
    }
    
public:
    QueueCallbackFunction _callbackQueue;
    InferFlag flag_ = InferFlag::GPU; //Default will use GPU to do inference task
    char* inputPtr_ = nullptr; //input buffer ptr
    char* outputPtr_ = nullptr; //output buffer pointer
    Time::time_point _startTime;
    Time::time_point _endTime;
};

#endif //INFER_TASK_HPP
