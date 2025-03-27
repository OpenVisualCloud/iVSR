/* Copyright (C) 2025 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

/**
 * @file ivsr.h
 * C API of Intel VSR SDK,
 * it is optimized on Intel Gen12+ GPU platforms.
 * Author: Renzhi.Jiang@intel.com
 */

#ifndef I_VSR_API_H
#define I_VSR_API_H

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * @brief vsr context
 */
typedef struct ivsr *ivsr_handle;

typedef struct ivsr_callback {
    void (*ivsr_cb)(void* args);
    void *args;
} ivsr_cb_t;

/**
 * @brief Intel VSR SDK version.
 *
 */
typedef struct ivsr_version {
    const char *api_version; //!< A string representing ibasicvsr sdk version>
} ivsr_version_t;

/**
 * @brief Status for Intel VSR SDK
 *
 */
typedef enum {
    OK              = 0,
    GENERAL_ERROR   = -1,
    UNKNOWN_ERROR   = -2,
    UNSUPPORTED_KEY = -3,
    UNSUPPORTED_CONFIG = -4,
    EXCEPTION_ERROR    = -5,
    UNSUPPORTED_SHAPE  = -6
} IVSRStatus;

/**
 * @enum vsr sdk supported key.
 * There are multiple configurations which contain resolutions,
 *     INPUT_RES - it's for patch-based solution
 *     RESHAPE_SETTINGS - it's to reshape the model's input tensor, NHW in current version
 *     INPUT_TENSOR_DESC_SETTING - input data's tensor description
 *     OUTPUT_TENSOR_DESC_SETTING - output data's tensor description
 *
 * RESHAPE_SETTINGS carries data for BATCH, WIDTH, HEIGH, in NHW format.
 * We may extent the type from one vector to a structure which specifies layout and different dimensions
 *
 */
typedef enum {
    INPUT_MODEL      = 0x1, //!< Required. Path to the input model file>
    TARGET_DEVICE    = 0x2, //!< Required. Device to run the inference>
    BATCH_NUM        = 0x3, //!< Not Enabled Yet>
    VERBOSE_LEVEL    = 0x4, //!< Not Enabled Yet>
    CUSTOM_LIB       = 0x5, //!< Optional. Path to extension lib file, required for loading Extended BasicVSR model>
    CLDNN_CONFIG     = 0x6, //!< Optional. Path to custom op xml file, required for loading Extended BasicVSR model>
    INFER_REQ_NUMBER = 0x7, //!< Optional. To specify inference request number>
    PRECISION        = 0x8, //!< Optional. To set inference precision for hardware>
    RESHAPE_SETTINGS = 0x9, //!< Optional. To set reshape setting for the input model>
    INPUT_RES        = 0xA, //!< Required. To specify the input frame resolution>
    INPUT_TENSOR_DESC_SETTING     = 0xB, //!< Optional. To set input tensor description>
    OUTPUT_TENSOR_DESC_SETTING    = 0xC, //!< Optional. To set output tensor description>
    NUM_STREAMS      = 0xD, //!< Optional. To specify number of execution streams for the throughput mode.>
} IVSRConfigKey;

typedef enum {
    IVSR_VERSION       = 0x1, //!< Key to access the version of the IVSR SDK.
    INPUT_TENSOR_DESC  = 0x2, //!< Key to access the description of the input tensor.
    OUTPUT_TENSOR_DESC = 0x3, //!< Key to access the description of the output tensor.
    NUM_INPUT_FRAMES   = 0x4, //!< Key to access the number of input frames.
    INPUT_DIMS         = 0x5, //!< Key to access the dimensions of the input tensor.
    OUTPUT_DIMS        = 0x6  //!< Key to access the dimensions of the output tensor.
} IVSRAttrKey;

/**
 * @struct ivsr_config
 * @brief Represents a configuration entry for IVSR.
 *
 * This structure is used to store a configuration key-value pair for IVSR.
 * Each entry can point to the next configuration entry, forming a linked list.
 *
 * @var ivsr_config::key
 * The configuration key of type IVSRConfigKey.
 *
 * @var ivsr_config::value
 * A pointer to the configuration value.
 *
 * @var ivsr_config::next
 * A pointer to the next configuration entry in the linked list.
 */
typedef struct ivsr_config {
    IVSRConfigKey key;
    const void *value;
    struct ivsr_config *next;
} ivsr_config_t;

typedef struct tensor_desc {
    char precision[20];          //!< A character array specifying the precision of the tensor (e.g., "FP32", "INT8").
    char layout[20];             //!< A character array specifying the layout of the tensor (e.g., "NCHW", "NHWC").
    char tensor_color_format[20];//!< A character array specifying the color format of the tensor (e.g., "RGB", "BGR").
    char model_color_format[20]; //!< A character array specifying the color format used by the model (e.g., "RGB", "BGR").
    float scale;                 //!< A floating-point value representing the scale factor of the tensor.
    uint8_t dimension;           //!< An unsigned 8-bit integer representing the number of dimensions of the tensor.
    size_t shape[8];             //!< An array of size_t values representing the shape of the tensor. The maximum number of dimensions is 8.
} tensor_desc_t;

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initializes the IVSR system with the given configuration.
 *
 * This function sets up the IVSR system based on the provided configuration
 * parameters and returns a handle to the initialized system.
 *
 * @param configs Pointer to the configuration structure containing initialization parameters.
 * @param handle Pointer to a handle that will be initialized and returned by the function.
 * @return IVSRStatus indicating the success or failure of the initialization process.
 */
IVSRStatus ivsr_init(ivsr_config_t *configs, ivsr_handle *handle);

/**
 * @brief Processes input data and produces output data using the specified IVSR handle.
 *
 * @param handle The IVSR handle used for processing.
 * @param input_data Pointer to the input data to be processed.
 * @param output_data Pointer to the buffer where the processed output data will be stored.
 * @param cb Pointer to a callback function to be called during processing.
 * @return IVSRStatus indicating the success or failure of the processing operation.
 */
IVSRStatus ivsr_process(ivsr_handle handle, char* input_data, char* output_data, ivsr_cb_t* cb);

/**
 * @brief Asynchronously processes input data and produces output data.
 *
 * This function initiates an asynchronous processing operation using the given handle.
 * The input data is processed and the result is stored in the output data buffer.
 * A callback function is invoked upon completion of the processing.
 *
 * @param handle The handle to the IVSR instance.
 * @param input_data Pointer to the input data buffer.
 * @param output_data Pointer to the output data buffer.
 * @param cb Pointer to the callback function to be called upon completion.
 * @return IVSRStatus indicating the status of the operation.
 */
IVSRStatus ivsr_process_async(ivsr_handle handle, char* input_data, char* output_data, ivsr_cb_t* cb);

/**
 * @brief Reconfigures the IVSR system with the provided configurations.
 *
 * This function updates the IVSR system settings based on the new configurations
 * provided through the `configs` parameter. It is essential to ensure that the
 * handle and configurations are valid before calling this function.
 *
 * @param handle The handle to the IVSR system instance.
 * @param configs A pointer to an ivsr_config_t structure containing the new configurations.
 * @return IVSRStatus indicating the success or failure of the reconfiguration process.
 */
IVSRStatus ivsr_reconfig(ivsr_handle handle, ivsr_config_t* configs);

/**
 * @brief Retrieves the attribute value associated with a given key from the specified IVSR handle.
 *
 * @param handle The IVSR handle from which to retrieve the attribute.
 * @param key The key identifying the attribute to retrieve.
 * @param value A pointer to a memory location where the attribute value will be stored.
 * @return IVSRStatus indicating the success or failure of the operation.
 */
IVSRStatus ivsr_get_attr(ivsr_handle handle, IVSRAttrKey key, void* value);

/**
 * @brief Deinitializes the IVSR system and releases associated resources.
 *
 * This function should be called to properly clean up and release resources
 * associated with the IVSR system. After calling this function, the handle
 * should not be used again unless it is reinitialized.
 *
 * @param handle The handle to the IVSR system to be deinitialized.
 * @return IVSRStatus indicating the success or failure of the deinitialization process.
 */
IVSRStatus ivsr_deinit(ivsr_handle handle);


#ifdef __cplusplus
}
#endif

#endif //I_VSR_API_H
