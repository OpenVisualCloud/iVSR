// Copyright (C) 2022-2023 Intel Corporation

/**
 * @file openvino_engine.h
 * openvino backend inference API,
 * it is the wrapper of backend inference API.
 */

#ifndef OV_ENGINE_HPP
#define OV_ENGINE_HPP

#include <condition_variable>
#include <queue>
#include "engine.hpp"
#include "openvino/openvino.hpp"
#include "openvino/pass/manager.hpp"
#include "openvino/pass/make_stateful.hpp"
#include "openvino/core/layout.hpp"

typedef std::function<void(size_t id)>
    CallbackFunction;
class inferReqWrap final {
public:
    using Ptr = std::shared_ptr<inferReqWrap>;
    explicit inferReqWrap(ov::CompiledModel& model, size_t id,CallbackFunction callback)
    : id_(id), request_(model.create_infer_request()),callback_(callback) {}

    void start_async() {
	startTime_ = Time::now();
        request_.start_async();
    }

    void end_time() {
        endTime_ = Time::now();
    }
    double get_execution_time_in_milliseconds() const {
        auto execTime = std::chrono::duration_cast<ns>(endTime_ - startTime_);
        return static_cast<double>(execTime.count()) * 0.000001;
    }

    void infer() {
        request_.infer();
        callback_(id_);
    }

    ov::Tensor get_tensor(const std::string& name) {
        return request_.get_tensor(name);
    }

    void set_input_tensor(const ov::Tensor& data) {
        request_.set_input_tensor(data);
    }

    void set_output_tensor(const ov::Tensor& data) {
        request_.set_output_tensor(data);
    }

    ov::Tensor get_output_tensor() {
        return request_.get_output_tensor();
    }

    ov::Tensor get_input_tensor() {
        return request_.get_input_tensor();
    }

    void set_tensor(const std::string& name, const ov::Tensor& data) {
        request_.set_tensor(name, data);
    }

    void set_callback(std::function<void(std::exception_ptr)> callback) {
        request_.set_callback(std::move(callback));
    }
    void call_back(){
        callback_(id_);
    }
private:
    ov::InferRequest request_;
    size_t id_;
    Time::time_point startTime_;
    Time::time_point endTime_;
    CallbackFunction callback_;
};


class ov_engine : public engine {
public:
    ov_engine(std::string device,
              std::string model_path,
              std::string custom_lib,
              std::map<std::string, ov::AnyMap> configs,
              const std::vector<size_t>& reshape_settings)
        : engine(device),
          model_path_(model_path),
          custom_lib_(custom_lib),
          configs_(configs),
          reshape_settings_(reshape_settings) {
        //init();
    }

    IBasicVSRStatus init();

    IBasicVSRStatus run(InferTask::Ptr task);

    IBasicVSRStatus get_attr(std::string key, void* value);

    inferReqWrap::Ptr get_idle_request() {
        std::unique_lock<std::mutex> lock(mutex_);
#ifdef ENABLE_LOG
        std::cout << "[Trace]: " << "idleIds size: " <<idleIds_.size() << std::endl;
#endif
        cv_.wait(lock, [this] {
            return idleIds_.size() > 0;
        });
        auto request = requests_.at(idleIds_.front());
        idleIds_.pop();
        return request;
    }
    void put_idle_request(size_t id){
        std::unique_lock<std::mutex> lock(mutex_);
        idleIds_.push(id);
#ifdef ENABLE_LOG
        std::cout << "[Trace]: " << "put_idle_request: idleIds size: " << idleIds_.size() << std::endl;
#endif
        cv_.notify_one();
    }

    void wait_all() {
#ifdef ENABLE_LOG
        std::cout << "[Trace]: " << "ov_engine wait_all: " << "idleIds_ size:" << idleIds_.size() << " requests_ size:" << requests_.size() << std::endl;
#endif
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] {
            return idleIds_.size() == requests_.size();
        });
    }

    ~ov_engine(){
        requests_.clear();
    }
    
private:

    //infer request queue length
    const int queueLen_ = 256;
    std::queue<size_t> idleIds_;
    std::vector<inferReqWrap::Ptr> requests_;
    std::mutex mutex_;
    std::condition_variable cv_;
    //configurations for openvino instances.
    std::map<std::string, ov::AnyMap> configs_;
    ov::Core instance_;
    std::vector<size_t> reshape_settings_;

    std::string custom_lib_;
    std::string model_path_;

    ov::Output<ov::Node> input_;
    ov::Output<ov::Node> output_;
};

#endif //OV_ENGINE_HPP
