// Copyright (C) 2022-2023 Intel Corporation

/**
 * @file openvino_engine.cpp
 * openvino backend inference implementation
 * it is the wrapper of backend inference API.
 */
#include <unistd.h>
#include <cstring>
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
        // Try private method
        std::vector<char> packed_buffer;
        std::vector<char> xml_buffer;
        // Created model object shares the weights with the weights object. Thus, do not create weights on temporary
        // data that can be freed later, since the model constant data will point to an invalid memory.
        static std::vector<char> bin_buffer{};
        long expiration = 0;

        if (irguard::system_conf_check() != irguard::OK) {
            std::cerr << "Please contact the provider!" << std::endl;
            exit(-1);
        }

        if (irguard::load_file_to_buffer(model_path_, packed_buffer) != irguard::OK) {
            std::cerr << "Failed to load " << model_path_ << "." << std::endl;
            exit(-1);
        }
        expiration = irguard::unpack(packed_buffer, xml_buffer, bin_buffer);
        auto now =
            std::chrono::duration_cast<std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch())
                .count();
        if (expiration - now < 0) {
            std::cerr << "The model is out of date. Please contact the provider!" << std::endl;
            exit(-1);
        }

        std::string str_model(xml_buffer.begin(), xml_buffer.end());
        model = instance_.read_model(str_model, ov::Tensor(ov::element::u8, {bin_buffer.size()}, bin_buffer.data()));
    }

    input_ = model->input();
    output_ = model->output();

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
        std::cout << "[PERF] " << "Inference Latency: " << latency << "ms, Throughput: " << double_to_string(3 * 1000.0 / latency) << "FPS" << std::endl;
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
    if(key == "model_inputs"){
        ov::Shape* input_shape = (ov::Shape*) value;
        auto shape = input_.get_shape();
        //@djx add for edsr
        if(shape.size() < 5)
            shape.insert(shape.begin(), 1);
        *input_shape = shape;
    }
    else if(key == "model_outputs"){
        ov::Shape* output_shape = ( ov::Shape* ) value;
        //@djx add for edsr 
        auto shape = output_.get_shape();
        if(shape.size() < 5)
            shape.insert(shape.begin(), 1);
        *output_shape = shape;
    }
    else if(key == "input_dims"){
        auto input_shape = input_.get_shape();
        //@djx add for edsr
        if(input_shape.size() < 5)
            input_shape.insert(input_shape.begin(), 1);
        int* dims = (int*) value;
        (*dims) = input_shape.size();
    }
    else if(key == "output_dims"){
        auto output_shape = output_.get_shape();
        //@djx add for edsr
        if(output_shape.size() < 5)
            output_shape.insert(output_shape.begin(), 1);
        int* dims = (int*) value;
        (*dims) = output_shape.size();
    }
    else{
        return ERROR;
    }
    return SUCCESS;
}
