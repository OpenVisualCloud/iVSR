// Copyright (C) 2022-2023 Intel Corporation

/**
 * @file engine.h
 * backend inference API,
 * it is the wrapper of backend inference API.
 */

#ifndef COMMON_ENGINE_HPP
#define COMMON_ENGINE_HPP

#include "utils.hpp"
#include "InferTask.hpp"
#include <string>
#include <vector>
#include <memory>

using namespace std;

class engine {
public:
    using Ptr = std::shared_ptr<engine>;
    /**
     * @brief Construct the engine object with device information
     * 
     * @param device 
     */
    engine(std::string device) : device_(device) {}

    /**
     * @brief initialize the engine and prepare needed resources.
     * 
     * @param model_path 
     * @return IBasicVSRStatus 
     */
    virtual IBasicVSRStatus init() = 0;

    /**
     * @brief Infer one task
     * 
     * @param task 
     * @return IBasicVSRStatus 
     */
    virtual IBasicVSRStatus run(InferTask::Ptr task) = 0;

    /**
     * @brief Get the engine attribute information.
     * 
     * @param key 
     * @param value 
     * @return IBasicVSRStatus 
     */
    // virtual IBasicVSRStatus get_attr(std::string key, std::string &value) = 0;
    virtual IBasicVSRStatus get_attr(std::string key, void* value)=0;

    virtual void wait_all() = 0;

    virtual ~engine(){}
    
protected:
    std::string device_;

};

#endif //COMMON_ENGINE_HPP