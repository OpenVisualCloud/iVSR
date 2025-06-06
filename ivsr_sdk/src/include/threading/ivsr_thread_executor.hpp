/* Copyright (C) 2025 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

/**
 * @file ivsr_thread_executor.hpp
 * @brief A header file for thread pool implementation.
 */

#pragma once

#include <memory>
#include <string>
#include <functional>
#include <vector>

#include "ivsr_thread_local.hpp"
#include "../engine.hpp"
#include "../ov_engine.hpp"

namespace IVSRThread {

// using Task = std::function<void()>;
using Task = InferTask::Ptr;

struct Config {
    std::string _name;
    int _threads = 5;  //!< Number of threads.

    Config(std::string name = "IVSRThreadsExecutor", int threads = 1) : _name(name), _threads(threads){};
};

/**
 * @class IVSRThreadExecutor
 * @brief Thread executor implementation.
 *        It implements a common thread pool.
 */
class IVSRThreadExecutor {
public:
    /**
     * @brief A shared pointer to a IVSRThreadExecutor object
     */
    using Ptr = std::shared_ptr<IVSRThreadExecutor>;
    using CallbackFunc = std::function<void()>;

    /**
     * @brief Constructor
     * @param config Thread executor parameters
     */
    explicit IVSRThreadExecutor(const Config& config, engine<ov_engine>* engine);

    /**
     * @brief A class destructor
     */
    ~IVSRThreadExecutor();

    /**
     * @brief interface to enqueue task
     */
    void Enqueue(Task task);

    /**
     * @brief interface to execute the task
     */
    void Execute(Task task);

    /**
     * @brief interface to create task
     */
    Task CreateTask(char* inBuf, char* outBuf, InferFlag flag, ivsr_cb_t* cb = NULL);

    /**
     * @brief interface to sync all the tasks
     */
    void wait_all(int patchSize);

    /**
     * @brief interface to get total duration
     */
    double get_duration_in_milliseconds();

private:
    struct Impl;
    std::unique_ptr<Impl> _impl;
};

}  // namespace IVSRThread
