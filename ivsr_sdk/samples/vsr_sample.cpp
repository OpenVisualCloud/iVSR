#include<string>
#include<dirent.h>
#include<iostream>
#include<unistd.h>
#include "opencv2/opencv.hpp"
#include <opencv2/core/utility.hpp>
#include "ivsr.h"
#include "utils.hpp"
#include "stdlib.h"
#include <chrono>
#include <ctime>
#include <mutex>

typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::nanoseconds ns;


const std::string keys =
    "{h                 | | Print Help Message}"
    "{model_path        | | Required. Path to an openvino ir model(.xml).}"
    "{data_path         | | Required. Path to a folder with images for inference.}"
    "{extension         | | Required for CPU custom layers. Absolute path to a shared library with the kernels implementations. }"
    "{device            |CPU| Optional. Specify a target device to infer on, default: CPU. Use MULTI:<comma-separated_devices_list> format to specify MULTI device}"
    "{save_predictions  |false| Optional. Whether to save the infer results to <save_path> or not.}"
    "{save_path         |./outputs| Optional. Path to a folder to save predictions.}"
    "{cldnn_config      | | Required for GPU custom kernels. Absolute path to an .xml file with the kernels description.}"
    "{nig               |1| Optional. Number of input data groups for inference. }"
    "{scale_factor      |2| Optional. The ratio of the size of the image before scaling (original size) to the size of the image after scaling (new size).}"
   ;

bool checkPath(std::string path){
    DIR *pDir;
    if(!(pDir = opendir(path.c_str())) || path[path.size() - 1] == '/')
        return false;
    return true;
}


int getFileNames(std::string path,std::vector<std::string>& filenames)
{
    DIR *pDir;
    struct dirent* ptr;
    if(!(pDir = opendir(path.c_str())))
        return -1;
    while((ptr = readdir(pDir))!=0) {
        if (strcmp(ptr->d_name, ".") != 0 && strcmp(ptr->d_name, "..") != 0)
            filenames.push_back(ptr->d_name);
    }
    sort(filenames.begin(), filenames.end());
    closedir(pDir);
    return 0;
}

// input:   n images with BGR(RGB) 0-255 
// output:  NCHW Matrix with RGB(BGR) 0-1
cv::Mat blobFromImages(std::vector<cv::Mat>& images, double scaleFactor,
                   bool swapRB)
{
    for (int i = 0; i < images.size(); i++) 
        if(images[i].depth() == CV_8U) 
            images[i].convertTo(images[i], CV_32F, scaleFactor);

    size_t nimages = images.size();
    cv::Mat image0 = images[0];
    int nch = image0.channels();
    int sz[] = { (int)nimages, nch, image0.rows, image0.cols };
    cv::Mat blob;
    blob.create(4, sz, CV_32F);
    cv::Mat ch[3];

    for(size_t i = 0; i < nimages; i++ )
    {
        const cv::Mat& image = images[i];
        CV_Assert(image.depth() == CV_32F);
        nch = image.channels();
        CV_Assert(nch == 3);
        CV_Assert(image.size() == image0.size());

        for( int j = 0; j < nch; j++ )
            ch[j] = cv::Mat(image.rows, image.cols, CV_32F, blob.ptr((int)i, j));
        if(swapRB)
            std::swap(ch[0], ch[2]);
        cv::split(image, ch);
    }
    
    return blob;
}

void imagesFromBlob(const cv::Mat& blob_, std::vector<cv::Mat>& images_)
{
    // A blob is a 4 dimensional matrix in floating point precision
    // blob_[0] = batchSize = nbOfImages
    // blob_[1] = nbOfChannels
    // blob_[2] = height
    // blob_[3] = width
    // output : BGR HWC3 image lists
    CV_Assert(blob_.depth() == CV_8U);
    CV_Assert(blob_.dims == 4);
    CV_Assert(blob_.size[1] == 3);

    int sz[] = {blob_.size[2], blob_.size[3]};
    cv::Mat vectorOfChannels[3];
    for (int n = 0; n < blob_.size[0]; ++n)
    {
        for (int c = 0; c < 3; ++c)
        {
            cv::Mat curChannel(2, sz, CV_8U, (void *)blob_.ptr<uchar>(n, c));
            vectorOfChannels[2 - c] = curChannel;   // BGR
        }
        cv::Mat curImage;
        cv::merge(vectorOfChannels, 3, curImage);
        images_.push_back(curImage);
    }
}

std::mutex _mutex;
int count = 0;
struct callback_args{
    int flag;
    int nif;
    Time::time_point time;
    callback_args(){}
    callback_args(int f, int nif, Time::time_point t):flag(f),nif(nif),time(t){}
};


void completion_callback (void *args)
{
#ifdef ENABLE_LOG
    std::cout << "[Trace]: "<< "vsr_sample callback called." << std::endl;
#endif
    callback_args * cb_args = (callback_args*)args;
    cb_args->flag = 1;

    {
        std::lock_guard<std::mutex> lock(_mutex);
        count += 1;
    }
#ifdef ENABLE_PERF
    auto duration = get_duration_ms_till_now(cb_args->time);
    std::cout << "Finished group id: " << (count - 1) <<std::endl;
    std::cout << "[PERF] " << "Process Latency: " << double_to_string(duration) <<"ms"<<std::endl;
    std::cout << "[PERF] " << "Process Throughput: " << double_to_string(cb_args->nif * 1000.0 / duration) <<"FPS"<<std::endl;
#endif
}

bool commandLineCheck(int argc, char**argv,std::string keys){
    for(int i = 1; i < argc; i++){
        std::string arg(argv[i]);
        int start_pos = arg.find("--");
        int end_pos = arg.find("=");
        if(start_pos ==-1){
            return false;
        }
        else if(end_pos == -1){
            end_pos = arg.length();
        }
        std::string commandArg = arg.substr(start_pos+2,end_pos - start_pos -2);
        int pos = keys.find(commandArg,0);
        if(pos < 0 || pos >= keys.length()){
            std::cout<<"Error command parameter: --" << commandArg <<std::endl;
            return false;
        }
    }
    return true;
}

int main(int argc, char** argv){
    // -------- Parsing and validation of input arguments --------
    cv::CommandLineParser parser(argc, argv, keys);
    if (parser.has("h") || argc == 1)
    {
        parser.printMessage();
        return 0;
    }
    std::string data_path = parser.get<std::string>("data_path");
    int nig = parser.get<int>("nig");
    // int nif = parser.get<int>("nif");
    std::string help = parser.get<std::string>("h");
    bool save_predictions = parser.get<bool>("save_predictions");
    std::string save_path = parser.get<std::string>("save_path");

    // vsr scale
    int scaleFactor = parser.get<int>("scale_factor");

    if (!parser.check() || !commandLineCheck(argc,argv,keys))
    {
        std::cout << "Error in commandline!" << std::endl;
        parser.printErrors();
        parser.printMessage();
        return -1;
    }
    // input and output path check 
    if(!checkPath(data_path)){
        std::cout << "Invalid input directory path!" << std::endl;
        std::cout << "Directory NOT found or PATH ended with '/' " << std::endl;
        std::cout << "Please confirm your path is existed and does NOT end with '/' " << std::endl;
        return -1;
    }
    if(save_predictions && !checkPath(save_path)){
        std::cout << "Invalid output directory path!" << std::endl;
        std::cout << "Directory NOT found or PATH ended with '/' " << std::endl;
        std::cout << "Please confirm your path is existed and does NOT end with '/' " << std::endl;
        return -1;
    }
    // 1. set ivsr config
    ivsr_config_t *config_device = nullptr, *config_customlib = nullptr, *config_cldnn = nullptr;

    ivsr_config_t *config = new ivsr_config_t();
    // - required configs
    std::string model_path = parser.get<std::string>("model_path");
    config->key = IVSRConfigKey::INPUT_MODEL;
    config->value = model_path.c_str();
    config->next = nullptr;

    std::string device = parser.get<std::string>("device");
    config_device= (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
    config_device->key = IVSRConfigKey::TARGET_DEVICE;
    config_device->value = device.c_str();
    config_device->next = nullptr;
    config->next = config_device;

    // - optional configs
    std::string extension = parser.get<std::string>("extension");
    if (extension != "") {
        config_customlib= (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
        config_customlib->next = nullptr;
        config_customlib->key = IVSRConfigKey::CUSTOM_LIB;
        config_customlib->value = extension.c_str();
        config_device->next = config_customlib;
    }
    
    std::string cldnn_config = parser.get<std::string>("cldnn_config");
    if (extension != "" && cldnn_config != "") {
        config_cldnn= (ivsr_config_t*)malloc(sizeof(ivsr_config_t));
        config_cldnn->next = nullptr;
        config_cldnn->key = IVSRConfigKey::CLDNN_CONFIG;
        config_cldnn->value = cldnn_config.c_str();
        config_customlib->next = config_cldnn;
    }

    // 2. initialize ivsr
    ivsr_handle handle = nullptr;
    auto res = ivsr_init(config, &handle);
    if(res < 0){
        std::cout <<"Failed to initialize ivsr engine!" <<std::endl;
        return -1;
    }

    int nif = 0;
    res = ivsr_get_attr(handle, IVSRAttrKey::NUM_INPUT_FRAMES, &nif);
    if(res < 0){
        std::cout <<"Failed to get the attribute: " << IVSRAttrKey::NUM_INPUT_FRAMES <<std::endl;
        return -1;
    }
    // 3. prepare input data
    // 3.1 Get file names
    std::cout << "[INFO] " << "Inputs Path: " << data_path << std::endl;
    std::vector<std::string> filePathList;
    getFileNames(data_path, filePathList);
    if(filePathList.size() < nif) {
        std::cout << "Not enough frames for an inference!" << std::endl;
        std::cout << "At least NIF frames in the data_path are needed!" << std::endl;
        return -1;
    }
    std::vector<cv::Mat> inputDataList;
    std::vector<cv::Mat> outputDataList;
    int oriHeight =0,oriWidth=0;
    for(int idx =0; idx < filePathList.size() && idx < nig * nif; idx += nif){
        // 3.2 Read input images and preprocess with opencv
        std::vector<cv::Mat> inMatList;
        for(int i = 0; i < nif; i++){
            std::string filePath = data_path + "/" + filePathList[idx + i];
#ifdef ENABLE_LOG
            std::cout << "Reading image: " << filePath << std::endl;
#endif
            cv::Mat img = cv::imread(filePath, cv::IMREAD_COLOR);
            inMatList.push_back(img);
        } 
     
        // check images' shape
        oriHeight = inMatList[0].rows, oriWidth = inMatList[0].cols;
        /* how to check image size and model input? */

        // refer to cv::dnn::blobFromImages
        cv::Mat inputNCHW = blobFromImages(inMatList, 1.0/255, true);
        int sz[] = { 1, nif, 3, oriHeight, oriWidth };
        cv::Mat inputImg(5, sz, CV_32F, (char *)inputNCHW.data);
        inputDataList.push_back(inputImg.clone());

        int outputSize[] = {1, nif, 3, oriHeight * scaleFactor, oriWidth * scaleFactor};
        cv::Mat outputImg = cv::Mat::zeros(5, outputSize, CV_32F);
        outputDataList.push_back(outputImg.clone());
    }

    std::cout << "[INFO] " << "Inference start: " << std::endl;
    
    int input_size[] = { 1, nif, 3, oriHeight, oriWidth };

    int id = 0;
#ifdef ENABLE_PERF
    auto totalStartTime = Time::now();
#endif
    for (; id < inputDataList.size() && id < outputDataList.size();id++){
        auto inputImg = inputDataList[id];
        auto outputImg = outputDataList[id];
        ivsr_cb_t cb;
        auto startTime = Time::now();
        callback_args cb_args(0,nif,startTime);
        cb.ivsr_cb = completion_callback;
        cb.args = (void*)(&cb_args);
        // 4. inference  
        auto result = ivsr_process(handle, (char *)inputImg.data, (char *)outputImg.data, input_size, &cb);
        if(result < 0){
            std::cout <<"Failed to process the inference on input data seq." << id <<std::endl;
        }
    }

    //wait for the completion callback
    while (count != id) {
        usleep(100);
    }
#ifdef ENABLE_PERF
    auto duration = get_duration_ms_till_now(totalStartTime);
    std::cout << "[PERF] " << "Total processed groups: " << nig <<std::endl;
    std::cout << "[PERF] " << "Total latency for all input groups: " << double_to_string(duration) <<"ms"<<std::endl;
    std::cout << "[PERF] " << "Average throughput for all input groups: " << double_to_string(nig * nif * 1000.0 / duration) <<"FPS"<<std::endl;
#endif

    std::cout << "[INFO] " << "Inference finished" << std::endl;

    // save outputs
    if(save_predictions) {
        if(save_path == ""){
            std::cout << "save_path is needed!" << std::endl;
            return -1;
        }
        std::cout << "[INFO] " << " Saving outputs to path: " << save_path <<std::endl;
        for (int idx = 0; idx < outputDataList.size(); idx++){
            // 5. post process and save outputs
            auto outputImg = outputDataList[idx];
            outputImg.convertTo(outputImg, CV_8U, 255.0);
            int nchwSize[] = {nif, 3, oriHeight * scaleFactor, oriWidth * scaleFactor};
            cv::Mat outputNCHW(4, nchwSize, CV_8U, (void *)outputImg.data);
            std::vector<cv::Mat> outMatList;
            imagesFromBlob(outputNCHW, outMatList);

            // save group
            for(int i = 0; i < nif; i ++){
                std::string filePath = save_path + "/" + filePathList[idx * nif + i];
#ifdef ENABLE_LOG
            std::cout << "[Trace]: " << "Saving image: " << filePath <<std::endl;
#endif
                cv::imwrite(filePath, outMatList[i]);

            }  
        }
    }
    //release resources
    res = ivsr_deinit(handle);
    if(res < 0){
        std::cout <<"Failed to release resources!" <<std::endl;
        return -1;
    }
    while (config != nullptr) {
        ivsr_config_t *next = config->next;
        delete config;
        config = next;
    }
    delete handle;
    handle = nullptr;
    
    return 0;
}
