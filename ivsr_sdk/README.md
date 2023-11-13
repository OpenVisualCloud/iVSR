# Intel Video Super Resolution Development Kit


Intel Video Super Resolution Development Kit (iVSR SDK) is a SDK which incorporates state-of-the-art deep learning based super resolution algorithms.

The SDK Core consists of two parts, one is the patch solution part, the other is the task scheduler part. 
1. The patch solution part will split the frames into small patches, then the small patch will be wrapped as one inference task and put it in the task queue in the scheduler module. In addition, each small patch will have a flag to indicate which platform will be used for inference.
1. The task scheduler part will fetch task from the task queue and send the task to the corresponding hardware according to the flag set for each small patch.

The VSR SDK sample application supports to deliver super resolution algorithms on multi-HW devices, targeting to deliver a high quality and performance VSR system.

<br />

## **Feature Overview**

<!-- ![overview](./figs/iVSR_SDK.PNG) -->
<div align=center>
<img src="./figs/iVSR_SDK.PNG" width = 75% height = 75% />
</div>

<br />

## **API Introduction**


The iVSR toolkit only provides API for C. All available interfaces are listed in the following table for [overview](#overview). Please refer to [Detailed Description](#detailed-description) for more information.


### **Overview**

|Function name|Operation|
|:--|:--|
|[ivsr_init](#ivsr_init)|Initialize the iVSR environment.|
|[ivsr_process](#ivsr_process)|Perform a VSR task.|
|[ivsr_reconfig](#ivsr_reconfig)|Reset and re-config iVSR environment.|
|[ivsr_get_attr](#ivsr_get_attr)|Get the iVSR properties/attributes.|
|[ivsr_deinit](#ivsr_deinit)|De-initialize the resources allocated for the iVSR environment.|


### **Detailed Description**


#### **ivsr_init**

Initialize the iVSR environment.

**Syntax**

```C 
IVSRStatus ivsr_init(ivsr_config_t *configs, ivsr_handle *handle); 
```
**Parameters**

- `configs` Configurations to initialize the intel VSR SDK.
- `handle` A handle for VSR processing. 

**Description**

The method creates an iVSR handle to prepare VSR environment according to the configurations.

**Return Values**

 `IVSRStatus`	Return a status to indicate whether the initialization is successful or not.


#### **ivsr_process**

Perform a VSR task.

**Syntax**

```C
IVSRStatus ivsr_process(ivsr_handle handle, char* input_data, char* output_data, ivsr_cb_t* cb); 
```

**Parameters**

- `handle` A handle for VSR processing. 
- `input_data` Input data address for a VSR task.
- `output_data` Output data address for the VSR task output.
- `cb` A callback function for user to know something about the VSR task, e.g. indicating whether the VSR task has completed.

**Description**

The method performs VSR processing with the given input data and generates the output data.

**Return Values**

`IVSRStatus`	Return a status to indicate whether VSR processing is successful or not.


#### **ivsr_reconfig**

Reset and re-config iVSR environment.

**Syntax**

```C
IVSRStatus ivsr_reconfig(ivsr_handle handle, ivsr_config_t* configs); 
```

**Parameters**

- `handle` A handle for VSR processing.
- `configs`  Configurations to reset the VSR environment.

**Description**

 The method reconfigures the VSR environment.

**Return Values**

`IVSRStatus`	Return a status to indicate whether reconfiguration is successful or not.


#### **ivsr_get_attr**

Get the iVSR properties/attributes.

**Syntax**

```C
IVSRStatus ivsr_get_attr(ivsr_handle handle, IVSRAttrKey key, void* value); 
```

**Parameters**

- `handle` A handle for VSR processing.  
- `key` Name of a attribute/property.
- `value` Value of the attribute got by key.

**Description**

This method is used to get the properties/attributes of the VSR environment that the user wants to know about.

**Return Values**

`IVSRStatus`	Return the a status to indicate whether the attribute is got successfully.


#### **ivsr_deinit**

De-initialize the resources allocated for the iVSR environment.

**Syntax**

```C
IVSRStatus ivsr_deinit(ivsr_handle handle); 
```

**Parameters**

`handle` A handle for VSR processing.   

**Description**

The method deinitializes the handle and releases the resources allocated for iVSR process.


**Return Values**

`IVSRStatus`	Return the a status to indicate whether VSR deinitialization is successful.

<br />

##  **VSR Sample**


There is a simple C++ sample to perform BasicVSR inference on OpenVINO backend. You can reach the sample from `/workspace/ivsr/ivsr_sdk/bin/vsr_sample`. You can get the help messages by running `./vsr_sample -h`  and see the default settings of parameters.

|Option name|Desciption|Default value|Recommended value(s)|
|:--|:--|:--|:--|
|h|Print Help Message|||
|cldnn_config|Required. Path of CLDNN config.|None|< Path to OpenVINO >/flow_warp_custom_op/flow_warp.xml|
|data_path|Required. Input data path for inference.|None||
|device|Optional. Device to perform inference.|CPU|CPU or GPU or MULTI:GPU.0,GPU.1|
|extension|Optional. Extension (.so or .dll) path of custom operation.|None|< Path to basicvsr_sample>/lib/libcustom_extension.so|
|model_path|Required. Path of BasicVSR OpenVINO IR model (.xml).|None||
|nig|Optional. Number of input groups for inference.|1||
|save_path|Optional. Path to save predictions.|./outputs|If use the default value, make sure default path exists.|
|save_predictions|Optional. Whether to save the results to save_path.|false|If this option exists, results will be saved.|
|scale_factor|Optional. The ratio of the size of the image before scaling (original size) to the size of the image after scaling (new size).|2|For image enhancement model and if no resolution change, please set to 1.|

Please note that all the paths specified by options should exist and do not end up with '/'. Here are some examples to run BasicVSR inference on different devices:

```bash
# VSR sample on CPU
./vsr_sample --model_path=[your model.xml] --data_path=[folder contains low resolution images] --extension=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so --cldnn_config=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml --nig=3 --device=CPU          
# VSR sample on Single GPU
./vsr_sample --model_path=[your model.xml] --data_path=[folder contains low resolution images] --extension=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so --cldnn_config=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml --nig=3 --device=GPU
# VSR sample on Multiple-GPUs
./vsr_sample --model_path=[your model.xml] --data_path=[folder contains low resolution images] --extension=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/bin/intel64/Release/libcustom_extension.so --cldnn_config=/workspace/ivsr/ivsr_gpu_opt/based_on_openvino_2022.3/openvino/flow_warp_cl_kernel/flow_warp.xml --nig=3 --device=MULTI:GPU.0,GPU.1
```

<br />

##  **Test Cases**


There are some unit tests for the iVSR API. You can reach the unit tests from "`/workspace/ivsr/ivsr_sdk/bin/vsr_unit_test`". Since model is essential for inference, you need to prepare models (*.bin and *.xml ) to the same path of `vsr_unit_test` and rename the model files to " test_with_custom_op.xml" and " test_with_custom_op.bin".

You can perform unit tests by runing the following command:

```bash
./vsr_unit_test
```

Then you can obtain the test results with status <font color="#00dd00">PASSED</font> or <font color="#dd0000">FAILED</font>.

<br />

## **Set Up**

A Dockerfile is provided to set up the environment quickly and easily. You can refer to [Environment Set Up](./ENVIRONMENT.md) for details.

