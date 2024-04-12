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
#include <functional>

using namespace std;

template<typename Derived>
class engine {
private:
    // Function objects for type-erased calls to interface methods
    std::function<IBasicVSRStatus()> init_func;
    std::function<IBasicVSRStatus(InferTask::Ptr task)> run_func;
    std::function<void()> wait_all_func;
    Derived* _derived;

public:
    // Template constructor binds the provided methods of the derived engine implementation
    engine(Derived* derived)
        : _derived(derived),
          init_func([=]() -> IBasicVSRStatus { return _derived->init_impl(); }),
          run_func([=](InferTask::Ptr task) -> IBasicVSRStatus { return _derived->run_impl(task); }),
          wait_all_func([=]() { _derived->wait_all_impl(); })
    {}

    engine() = default;

    // Public interface methods call the type-erased std::function members
    IBasicVSRStatus init() {
        return init_func();
    }

    IBasicVSRStatus run(InferTask::Ptr task) {
        return run_func(task);
    }

    // The templated get_attr method delegates to the derived class's method
    template <typename T>
    IBasicVSRStatus get_attr(const std::string& key, T& value) {
        // Using CRTP style static_cast to delegate to the actual implementation provided by the derived class
        // For this to work, the derived class must implement get_attr_impl with the appropriate signature
        return _derived->get_attr_impl(key, value);
    }

    void wait_all() {
        wait_all_func();
    }

    Derived* get_impl() const { return _derived; }
};

#endif //COMMON_ENGINE_HPP
