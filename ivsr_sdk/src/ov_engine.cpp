// Copyright (C) 2022-2023 Intel Corporation

/**
 * @file openvino_engine.cpp
 * openvino backend inference implementation
 * it is the wrapper of backend inference API.
 */
#include <unistd.h>
#include <cstring>
#include <cassert>
#include "ov_engine.hpp"
#include "utils.hpp"
#include "omp.h"

#include <irguard.hpp>

typedef std::chrono::high_resolution_clock Time;

IBasicVSRStatus ov_engine::init()
{
    if (custom_lib_ != "")
        instance_.add_extension(custom_lib_);
    //set property for ov instance
    for (auto&& item : configs_) {
        instance_.set_property(item.first, item.second);
    }
    //read model
    std::shared_ptr<ov::Model> model;
    try {
        model = instance_.read_model(model_path_);
    } catch (const std::exception& e) {
        model = irguard::load_model(instance_, model_path_);
    }

    input_ = model->input();
    output_ = model->output();

    if (!reshape_settings_.empty()) {
        ov::PartialShape tensor_shape = input_.get_partial_shape();
        assert(tensor_shape.size() == reshape_settings_.size());
        ov::Dimension frame_w = reshape_settings_[reshape_settings_.size() - 1];
        ov::Dimension frame_h = reshape_settings_[reshape_settings_.size() - 2];
        ov::Dimension model_w = tensor_shape[tensor_shape.size()-1];
        ov::Dimension model_h = tensor_shape[tensor_shape.size()-2];
        if(frame_w!=model_w || frame_h!=model_h){
            tensor_shape = (ov::PartialShape)reshape_settings_;
    #ifdef ENABLE_LOG
            std::cout << "Model shape different with frame,reshape network to the frame size = [" << reshape_settings_[reshape_settings_.size() - 2] << "x"
                    << reshape_settings_[reshape_settings_.size() - 1] << "] " << std::endl;
    #endif
            model->reshape({{model->input().get_any_name(), tensor_shape}});
    #ifdef ENABLE_LOG
            std::cout<<"model reshape success!"<<std::endl;
    #endif
        }
    }

    //compile model
    auto compiledModel = instance_.compile_model(model, device_);

    for (size_t id = 0; id < queueLen_; id++) {
        requests_.push_back(std::make_shared<inferReqWrap>(compiledModel ,id,std::bind(&ov_engine::put_idle_request,
                                                                        this,
                                                                        std::placeholders::_1)));
        idleIds_.push(id);
    }
#ifdef ENABLE_LOG
    std::cout << "[Trace]: " << "ov_engine init successfully" << std::endl;
#endif 

    return SUCCESS;
}

IBasicVSRStatus ov_engine::run(InferTask::Ptr task) {
    //construct the input tensor
    if(task->inputPtr_ == nullptr || task->outputPtr_ == nullptr) {
        std::cout << "[Error]: " << "invalid input buffer pointer" << std::endl;
        return ERROR;
    }
    auto inferReq = get_idle_request();

    inferReq->set_callback([wp = std::weak_ptr<inferReqWrap>(inferReq),task](std::exception_ptr ex) {
        auto request = wp.lock();
#ifdef ENABLE_PERF
	request->end_time();
        auto latency = request->get_execution_time_in_milliseconds();
        size_t frame_num = (request->get_input_tensor()).get_shape()[(request->get_input_tensor().get_shape()).size()-4];
        std::cout << "[PERF] " << "Inference Latency: " << latency << "ms, Throughput: " << double_to_string(frame_num * 1000.0 / latency) << "FPS" << std::endl;
#endif

        if(ex) {
#ifdef ENABLE_LOG
        std::cout << "[Trace]: " << "Exception in infer request callback " << std::endl;
#endif
            try{
                // std::rethrow_exception(ex);
                throw ex;
            } catch(const std::exception& e) {
                std::cout << "Caught exception \"" << e.what() << "\"\n";
            }
        }
        auto cbTask = task;
        auto output_tensor = request->get_output_tensor();
        auto size = output_tensor.get_byte_size();

        //TODO: better way to do it to reduce memory copy.
        //reinvestigae openvino API for buffer sharing or expose the output buffer pointer to application
        //std::memcpy(cbTask->outputPtr_, (char*)output_tensor.data(), size);
        omp_set_num_threads(12);
        #pragma omp parallel for 
        for(int i = 0; i < 12; i++) {
            std::memcpy(cbTask->outputPtr_ + i * size / 12, (char*)output_tensor.data() + i * size / 12,  size / 12);
        }

#ifdef ENABLE_LOG
        std::cout << "[Trace]: " << "infer request callback: Memory Copy Finsihed!" << std::endl;
#endif
        request->call_back();
        //call application callback function 
	cbTask->_callbackQueue();     
    });
    
#ifdef ENABLE_LOG
    std::cout << "[Trace]: " << "input: " << input_.get_element_type().get_type_name() << " " << input_.get_shape() << std::endl;
    std::cout << "[Trace]: " << "output: " << output_.get_element_type().get_type_name() << " " << output_.get_shape() << std::endl;
#endif

    ov::Tensor input_tensor(input_.get_element_type(), input_.get_shape(), task->inputPtr_);
    inferReq->set_input_tensor(input_tensor);

    /**
     * output tensor can not set by this way.
    */
    //construct the output tensor
    //ov::Tensor output_tensor(output_.get_element_type(), output_.get_shape(), task->outputPtr_);
    //inferReq->set_output_tensor(output_tensor);
    inferReq->start_async();
    
#ifdef ENABLE_LOG
    std::cout << "[Trace]: " << "ov_engine run: start task inference" << std::endl;
#endif

    return SUCCESS;
}


IBasicVSRStatus ov_engine::get_attr(const std::string key, void* value) {
    auto extend_shape = [](ov::Shape &shape, size_t dims) {
        if (shape.size() < dims)
            for (size_t i = shape.size(); i < dims; i++)
                shape.insert(shape.begin(), 1);
    };

    if (key == "model_inputs") {
        ov::Shape* input_shape = (ov::Shape*)value;
        auto shape = input_.get_shape();
        extend_shape(shape, 5);
        *input_shape = shape;
    } else if (key == "model_outputs") {
        ov::Shape* output_shape = (ov::Shape*)value;
        auto shape = output_.get_shape();
        extend_shape(shape, 5);
        *output_shape = shape;
    } else if (key == "input_dims") {
        auto input_shape = input_.get_shape();
        size_t* dims = (size_t*)value;
        *dims = input_shape.size() < 5 ? 5 : input_shape.size();
    } else if (key == "output_dims") {
        auto output_shape = output_.get_shape();
        size_t* dims = (size_t*)value;
        *dims = output_shape.size() < 5 ? 5 : output_shape.size();
    } else {
        return ERROR;
    }
    return SUCCESS;
}
