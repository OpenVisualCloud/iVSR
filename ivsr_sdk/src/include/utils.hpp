// Copyright (C) 2022-2023 Intel Corporation

/**
 * @brief basic definition for ivsr
 * 
 */

#ifndef UTILS_HPP
#define UTILS_HPP

#include<string>
#include<dirent.h>
#include<iostream>
#include<unistd.h>
#include <chrono>
#include <string>
#include<iostream>

#include <chrono>
#include <iomanip>
// #include <map>
// #include <openvino/openvino.hpp>
// #include <samples/slog.hpp>
#include <string>
#include <vector>

#include <string>
#include<iostream>

#include <chrono>
#include <iomanip>
// #include <map>
// #include <openvino/openvino.hpp>
// #include <samples/slog.hpp>
#include <string>
#include <vector>

#include <string>
#include<iostream>

#include <chrono>
#include <iomanip>
// #include <map>
// #include <openvino/openvino.hpp>
// #include <samples/slog.hpp>
#include <string>
#include <vector>

#include "ivsr.h"

/**
 * @enum IBASICVSRStatus
 * @brief This eunum contains codes for all possible returen value of iBascVSR.
 */
typedef enum {
    SUCCESS = 0,
    ERROR = -1
}IBasicVSRStatus;

typedef enum {
    NCHW = 0,
    NHWC = 1,
    BNCHW =2
}InputLayout;

typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::nanoseconds ns;


inline double get_duration_ms_till_now(Time::time_point& startTime) {
    return std::chrono::duration_cast<ns>(Time::now() - startTime).count() * 0.000001;
};
inline std::string double_to_string(const double number) {
    std::stringstream ss;
    ss << std::fixed << std::setprecision(2) << number;
    return ss.str();
};


inline std::vector<std::string> split(const std::string& s, char delim) {
    std::vector<std::string> result;
    std::stringstream ss(s);
    std::string item;

    while (getline(ss, item, delim)) {
        result.push_back(item);
    }
    return result;
};


inline void ivsr_status_log(IVSRStatus status, const char *log ){
    switch (status)
    {
    case IVSRStatus::GENERAL_ERROR:
        std::cout << "[General Error] NULL pointer exception " << log << "." << std::endl;
        break;
    case IVSRStatus::UNSUPPORTED_KEY:
        std::cout << "[Error] Unsupported keys " << log << ", please check the input keys."  <<std::endl;
        break;
    case IVSRStatus::UNSUPPORTED_CONFIG:
        std::cout << "[Error] Unsupported configs " << log << ", please check the input configs."  << std::endl;
        break;
    case IVSRStatus::UNKNOWN_ERROR:
        std::cout << "[Unknown Error] Process failed "<< log << "." << std::endl;
        break;
    case IVSRStatus::EXCEPTION_ERROR:
        std::cout << "[Exceptoin] Exception occurred "<< log << "." << std::endl;
        break;
    default:
        break;
    }
}

inline bool checkFile(std::string path){
    if(access(path.c_str(),0) == -1){
        std::cout << "Input " << path << "does not exists!" << std::endl;  
        return false;
    }
    return true;
}


#endif
