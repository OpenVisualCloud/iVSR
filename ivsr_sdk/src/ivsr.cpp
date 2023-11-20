#include<cassert>
#include<string>
#include<unordered_map>
#include<map>
#include "ivsr.h"
#include "engine.hpp"
#include "ov_engine.hpp"
#include "InferTask.hpp"
#include "ivsr_smart_patch.hpp"
#include "threading/ivsr_thread_executor.hpp"
#include "utils.hpp"
#include <mutex>

std::vector<std::string> parse_devices(const std::string& device_string) {
    std::string comma_separated_devices = device_string;
    auto colon = comma_separated_devices.find(":");
    std::vector<std::string> result;
    if (colon != std::string::npos) {
        auto target_device = comma_separated_devices.substr(0, colon);
        if (target_device == "AUTO" || target_device == "MULTI") {
            result.push_back(target_device);
        }
        auto bracket = comma_separated_devices.find("(");  // e.g. in BATCH:GPU(4)
        comma_separated_devices = comma_separated_devices.substr(colon + 1, bracket - colon - 1);
    }

    auto devices = split(comma_separated_devices, ',');
    result.insert(result.end(), devices.begin(), devices.end());
    return result;
}

void parse_engine_config(std::map<std::string, ov::AnyMap> &config, std::string device, std::string infer_precision, std::string cldnn_config){
    auto getDeviceTypeFromName = [](std::string device) -> std::string {
        return device.substr(0, device.find_first_of(".("));
    };
    if(device.find("GPU") != std::string::npos && !cldnn_config.empty()){
        if (!config.count("GPU"))
                config["GPU"] = {};
        config["GPU"]["CONFIG_FILE"] = cldnn_config;
    }
    
    auto devices = parse_devices(device);
    std::set<std::string> default_devices;
    for (auto& d : devices) {
        auto default_config = config.find(getDeviceTypeFromName(d));
        if (default_config != config.end()) {
            if (!config.count(d)) {
                config[d] = default_config->second;
                default_devices.emplace(default_config->first);
            }
        }
    }
    for (auto& d : default_devices) {
        config.erase(d);
    }
    // check if using the virtual device
    auto if_multi = std::find(devices.begin(), devices.end(), "MULTI") != devices.end();
    // remove the hardware devices if MULTI appears in the devices list.
    auto hardware_devices = devices;
    if (if_multi) {
	ivsr_version_t version;
        ov::Version ov_version = ov::get_openvino_version();
	std::string ov_buildNumber = std::string(ov_version.buildNumber);
        // Parse out the currect virtual device as the target device.
        std::string virtual_device = split(device, ':').at(0);
        auto iter_virtual = std::find(hardware_devices.begin(), hardware_devices.end(), virtual_device);
        hardware_devices.erase(iter_virtual);
	if (ov_buildNumber.find("2022.3") != std::string::npos) {
	    devices.clear();
            devices.push_back(virtual_device);
	} else {
	    devices = hardware_devices;
	}
    }
    // update config per device
    int nstream = 1; // set nstream = 1 for GPU what about CPU?
    //std::string infer_precision = "f32"; // set infer precision to f32
    //std::string infer_precision = "f16"; // set infer precision to f32
    for (auto& d : devices) {
        auto& device_config = config[d];
        // set throughput streams and infer precision for hardwares
        if (d == "MULTI" || d == "AUTO") {
            for(auto hd : hardware_devices){
                // construct device_config[hd] map and insert first property
                device_config.insert(ov::device::properties(hd, ov::num_streams(nstream)));
                // insert second property in device_config[hd]
                auto& property = device_config[hd].as<ov::AnyMap>();
                property.emplace(ov::hint::inference_precision(infer_precision));
            }
        }
        else if(d.find("GPU") != std::string::npos){ // GPU
            auto stream_key = ov::num_streams.name();
            device_config[stream_key] = nstream;
            device_config.emplace(ov::hint::inference_precision(infer_precision));
        }
        else{ // CPU 
            // insert inference precision to map device_config
            device_config.emplace(ov::hint::inference_precision(infer_precision));
        }

    }
}

struct ivsr{
    engine *inferEngine;
    IVSRThread::IVSRThreadExecutor *threadExecutor;
    std::unordered_map<std::string,const char*> vsr_config;
    PatchConfig patchConfig;
    bool patchSolution;
    ivsr():inferEngine(nullptr),threadExecutor(nullptr),patchSolution(false){}
};

IVSRStatus ivsr_init(ivsr_config_t *configs, ivsr_handle *handle){
    if(configs == nullptr || handle == nullptr){
        ivsr_status_log(IVSRStatus::GENERAL_ERROR,"in ivsr_init");
        return IVSRStatus::GENERAL_ERROR;
    }

    (*handle) = new ivsr();

    //TODO: replace w/ parseConfig() ??
    // 1.parse input config
    std::string model = "", device = "", batch = "", infer_precision = "";
    std::string verbose = "", custom_lib = "", cldnn_config = "";
    while(configs!=nullptr){
        IVSRStatus unsupported_status = IVSRStatus::OK;
        std::string unsupported_output = "";
        switch(configs->key){
            case IVSRConfigKey::INPUT_MODEL:
                model = std::string(configs->value);
                if(!checkFile(model)){
                    unsupported_status = IVSRStatus::UNSUPPORTED_CONFIG;
                    unsupported_output.append("INPUT_MODEL").append("=").append(configs->value);
                }
                std::cout << "[INFO] " << "Model Path:" << model << std::endl;
                break;
            case IVSRConfigKey::TARGET_DEVICE:
                device = configs->value;
                std::cout << "[INFO] " << "DEVICE:" << device << std::endl;
                break;
            case IVSRConfigKey::BATCH_NUM:
                batch = configs->value;
                break;
            case IVSRConfigKey::VERBOSE_LEVEL:
                verbose = configs->value;
                break;
            case IVSRConfigKey::CUSTOM_LIB:
                custom_lib = configs->value;
                if(!checkFile(custom_lib)){  // file not exists, inform out
                    unsupported_status = IVSRStatus::UNSUPPORTED_CONFIG;
                    unsupported_output.append("CUSTOM_LIB").append("=").append(configs->value);
                }
                break;
            case IVSRConfigKey::CLDNN_CONFIG:
                cldnn_config = configs->value;
                if(!checkFile(cldnn_config)){
                    unsupported_status = IVSRStatus::UNSUPPORTED_CONFIG;
                    unsupported_output.append("CLDNN_CONFIG").append("=").append(configs->value);
                }
                break;
            case IVSRConfigKey::PRECISION:
                infer_precision = configs->value;
                if(device.find("GPU") != std::string::npos){
                    if(infer_precision.compare("f32") != 0 && infer_precision.compare("f16") != 0){
                        ivsr_status_log(IVSRStatus::UNSUPPORTED_CONFIG,"for PRECISION=");
                        return IVSRStatus::UNSUPPORTED_CONFIG;
                    }
                }else{
                    if(infer_precision.compare("f32") != 0 && infer_precision.compare("bf16") != 0){
                        ivsr_status_log(IVSRStatus::UNSUPPORTED_CONFIG,"for PRECISION=");
                        return IVSRStatus::UNSUPPORTED_CONFIG;
                    }
                }
                std::cout << "[INFO] " << "PRECISION:" << infer_precision << std::endl;
                break;
            default:
                unsupported_status = IVSRStatus::UNSUPPORTED_KEY;
                unsupported_output.append(std::to_string(configs->key));
                break;
        }
        ivsr_status_log(unsupported_status, unsupported_output.c_str());

        configs = configs->next;
    }

    if (device == "") {
        ivsr_status_log(IVSRStatus::UNSUPPORTED_CONFIG,"for TARGET_DEVICE=");
        return IVSRStatus::UNSUPPORTED_CONFIG;
    }

    /**
     * Below code only is for OpenVINO engine
    */
    // 2.parse config for inference engine
    std::map<std::string, ov::AnyMap> engine_configs;
    parse_engine_config(engine_configs,device,infer_precision,cldnn_config);

    // 3.construct and initialization
    // - initialize inference engine
    (*handle)->inferEngine = new ov_engine(device, model, custom_lib, engine_configs);

    // -construct IVSRThreadExecutor object
    IVSRThread::Config executorConfig;
    (*handle)->threadExecutor = new IVSRThread::IVSRThreadExecutor(executorConfig, (*handle)->inferEngine);
    
    // -construct patch config
    int intput_dims = 0;
    (*handle)->inferEngine->get_attr("input_dims", &intput_dims); 
    ov::Shape model_inputs, model_outputs;
    (*handle)->inferEngine->get_attr("model_inputs",&model_inputs); // 1,3,3,1080,1920 (400,700)
    (*handle)->inferEngine->get_attr("model_outputs",&model_outputs); // 1,3,3,2160,3840 (800,1400)

    // --set patch configs
    int m_input_width = *(model_inputs.end() - 1);
    int m_input_height = *(model_inputs.end() - 2);
    int nif = *(model_inputs.end() - 4);
    int m_output_width = *(model_outputs.end() - 1);
    (*handle)->patchConfig.scale = m_output_width / m_input_width; // Note: do not support fractional SR 
    (*handle)->patchConfig.patchHeight = m_input_height;
    (*handle)->patchConfig.patchWidth = m_input_width;
    (*handle)->patchConfig.dims = intput_dims;
    (*handle)->patchConfig.nif = nif;

    return IVSRStatus::OK;
}

IVSRStatus ivsr_process(ivsr_handle handle, char* input_data, char* output_data, int* input_size, ivsr_cb_t* cb){
    if(input_data == nullptr){
        ivsr_status_log(IVSRStatus::GENERAL_ERROR, "in ivsr_process");
        return IVSRStatus::GENERAL_ERROR;
    }

    try{
        // get input data shape
        std::vector<int> input_data_shape; // {1,3,3,1080,1920}
        for(int i = 0; i < handle->patchConfig.dims; i++){
            input_data_shape.push_back(*(input_size + i));
        }

        // determine whether apply patch solution or not
        if(handle->patchConfig.patchHeight < *(input_data_shape.end()-2) || handle->patchConfig.patchWidth < *(input_data_shape.end()-1)){
            handle->patchSolution = true;
        }

        // smart patch inference
        SmartPatch* smartPatch = new SmartPatch(handle->patchConfig,input_data,output_data,input_data_shape,handle->patchSolution);
        // -prepare data
        auto res = smartPatch->generatePatch();
        if(res == -1){
            ivsr_status_log(IVSRStatus::UNKNOWN_ERROR, "in Smart Patch");
            return IVSRStatus::UNKNOWN_ERROR;
        }
        auto patchList = smartPatch->getInputPatches();
        auto outputPatchList = smartPatch->getOutputPatches();

#ifdef ENABLE_PERF 
    auto totalStartTime = Time::now();
#endif

	// -get data into infer task
        int idx = 0;
	for(; idx < patchList.size(); idx++ ){
#ifdef ENABLE_LOG
            std::cout << "[Trace]: " << "ivsr_process on patch: " << idx <<  std::endl;
#endif

	    std::shared_ptr<InferTask> task = handle->threadExecutor->CreateTask(patchList[idx], outputPatchList[idx], InferFlag::AUTO);
        handle->threadExecutor->Enqueue(task);
    }

	// -wait for all the tasks finish
        handle->threadExecutor->wait_all(patchList.size());	
#ifdef ENABLE_PERF 
        auto duration = get_duration_ms_till_now(totalStartTime);
        std::cout << "[PERF] " << "Patch inference with memory copy - Latency: " << double_to_string(duration) <<"ms"<<std::endl;
        std::cout << "[PERF] " << "Patch inference with memory copy - Throughput: " << double_to_string(3 * 1000.0 / duration) <<"FPS"<<std::endl;
#endif
// #ifdef ENABLE_PERF
// 	// -get total duration for all tasks
// 	      double totalDuration = handle->threadExecutor->get_duration_in_milliseconds();
//         double fps = 3 * 1000.0/totalDuration;

// 	      std::cout << "All tasks Total Latency for One Nig: " << double_to_string(totalDuration) <<"ms"<<std::endl;
//         std::cout << "All tasks in One Nig Throughput : " << double_to_string(fps) <<"FPS"<<std::endl;
// #endif
	// -restore output patches to images
        res = smartPatch->restoreImageFromPatches();
        if(res == -1){
            ivsr_status_log(IVSRStatus::UNKNOWN_ERROR, "in Smart Patch");
            return IVSRStatus::UNKNOWN_ERROR;
        }
        
        delete smartPatch;
        // notify user
        cb->ivsr_cb(cb->args);

    }catch(exception e){
        std::cout << "Error in ivsr_process" << std::endl;
        ivsr_status_log(IVSRStatus::EXCEPTION_ERROR, e.what());
        return IVSRStatus::UNKNOWN_ERROR;
    }
    
    return IVSRStatus::OK;
}


IVSRStatus ivsr_reconfig(ivsr_handle handle, ivsr_config_t* configs){
    if(configs == nullptr){
        ivsr_status_log(IVSRStatus::GENERAL_ERROR, "in ivsr_reconfig");
        return IVSRStatus::GENERAL_ERROR;
    }

    try{
        // reset config in container
        while(configs!=nullptr){
            switch(configs->key){
                case IVSRConfigKey::INPUT_MODEL:
                    handle->vsr_config["model"] = configs->value;
                    break;
                case IVSRConfigKey::TARGET_DEVICE:
                    handle->vsr_config["device"] = configs->value;
                    break;
                case IVSRConfigKey::BATCH_NUM:
                    handle->vsr_config["batch_num"] = configs->value;
                    break;
                case IVSRConfigKey::VERBOSE_LEVEL:
                    handle->vsr_config["verbose_level"] = configs->value;
                    break;
                case IVSRConfigKey::CUSTOM_LIB:
                    handle->vsr_config["custom_lib"] = configs->value;
                    break;
                case IVSRConfigKey::CLDNN_CONFIG:
                    handle->vsr_config["cldnn_config"] = configs->value;
                    break;
                default:
                    break;
            }
            configs = configs->next;
        }
        
        // reconfig ov_engine ?

    }catch(exception e){
        // std::cout << "Error in ivsr_reconfig" << std::endl;
        ivsr_status_log(IVSRStatus::EXCEPTION_ERROR, e.what());
        return IVSRStatus::UNKNOWN_ERROR;
    }

    return IVSRStatus::OK;
}

IVSRStatus ivsr_get_attr(ivsr_handle handle, IVSRAttrKey key, void* value){
    switch (key)
    {
        case IVSRAttrKey::IVSR_VERSION:
        {
            /* code */
            ivsr_version_t version;
            version.api_version = "ivsr_release:0.5";
            value = version.api_version;
            break;
        }
        case IVSRAttrKey::INPUT_TENSOR_DESC:
        {
            int* input_tensor_desc = (int*) value;
            ov::Shape input_shape;
            handle->inferEngine->get_attr("model_inputs",&input_shape);
            for(auto s : input_shape){
                *input_tensor_desc = s;
                input_tensor_desc++;
            }
            break;
        }
        case IVSRAttrKey::OUTPUT_TENSOR_DESC:
        {    
            int* output_tensor_desc = (int*) value;
            ov::Shape output_shape;
            handle->inferEngine->get_attr("model_outputs",&output_shape);
            for(auto s : output_shape){
                *output_tensor_desc = s;
                output_tensor_desc++;
            }
            break;
        }
        case IVSRAttrKey::NUM_INPUT_FRAMES:
        {    
            int* nif = (int*) value;
            *nif = handle->patchConfig.nif;
            break;
        }
        case IVSRAttrKey::INPUT_DIMS:
        {
            handle->inferEngine->get_attr("input_dims", value); 
            break;
        }
        case IVSRAttrKey::OUTPUT_DIMS:
        {
            handle->inferEngine->get_attr("output_dims",value);
            break;
        }
        default:
        {
            ivsr_status_log(IVSRStatus::UNSUPPORTED_KEY,(char*)key);
            return IVSRStatus::UNSUPPORTED_KEY;
        }
    }
    return IVSRStatus::OK;
}

IVSRStatus ivsr_deinit(ivsr_handle handle){
    try{
        if(handle->inferEngine){
            delete handle->inferEngine;
            handle->inferEngine = nullptr;
        }
        if(handle->threadExecutor){
            delete handle->threadExecutor;
            handle->threadExecutor = nullptr;
        }

    }catch(exception e){
        ivsr_status_log(IVSRStatus::EXCEPTION_ERROR, e.what());
        return IVSRStatus::UNKNOWN_ERROR;
    }

    return IVSRStatus::OK;
}

