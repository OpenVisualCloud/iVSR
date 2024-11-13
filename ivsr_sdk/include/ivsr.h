/********************************************************************************
* INTEL CONFIDENTIAL
* Copyright (C) 2023 Intel Corporation
*
* This software and the related documents are Intel copyrighted materials,
* and your use of them is governed by the express license under
* which they were provided to you ("License").Unless the License
* provides otherwise, you may not use, modify, copy, publish, distribute, disclose or
* transmit this software or the related documents without Intel's prior written permission.
*
* This software and the related documents are provided as is,
* with no express or implied warranties, other than those that are expressly stated in the License.
*******************************************************************************/

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

/**
 * @brief vsr context
 */
typedef struct ivsr *ivsr_handle;

// typedef void (*ivsr_cb)(void* args);

typedef struct ivsr_callback {
    void (*ivsr_cb)(void* args);
    void *args;
}ivsr_cb_t;

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
}IVSRStatus;

/**
 * @enum vsr sdk supported key.
 * 
 */
typedef enum {
    INPUT_MODEL      = 0x1, //!< Required, Path to the input model file>
    TARGET_DEVICE    = 0x2, //!< Required, device to run the inference>
    BATCH_NUM        = 0x3, //!< Not Enabled Yet>
    VERBOSE_LEVEL    = 0x4, //!< Not Enabled Yet>
    CUSTOM_LIB       = 0x5, //!< Path to extension lib file, required for loading Extended BasicVSR model>
    CLDNN_CONFIG     = 0x6, //!< Path to custom op xml file, required for loading Extended BasicVSR model>
    NUM_IFER_REQUEST = 0x7, //!< Not Enabled Yet>
    PRECISION        = 0x8, //!< Optional. To set inference precision for hardware>
    RESHAPE_SETTINGS = 0x9, //!< Optional. To set reshape setting for the input model>
    INPUT_RES        = 0xA, //!< Required, to specify the input frame resolution>
}IVSRConfigKey;

typedef enum {
    IVSR_VERSION       = 0x1,
    INPUT_TENSOR_DESC  = 0x2,
    OUTPUT_TENSOR_DESC = 0x3,
    NUM_INPUT_FRAMES   = 0x4,
    INPUT_DIMS         = 0x5,
    OUTPUT_DIMS        = 0x6
}IVSRAttrKey;

/**
 * @struct Intel VSR configuration.
 * 
 */
typedef struct ivsr_config {
    IVSRConfigKey key;
    const char *value;
    struct ivsr_config *next;
}ivsr_config_t;



#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief initialize the intel vsr sdk
 * 
 * @param configs configurations to initialize the intel vsr sdk.
 * @param handle handle used to process frames.
 * @return IVSRStatus 
 */
IVSRStatus ivsr_init(ivsr_config_t *configs, ivsr_handle *handle);

/**
 * @brief process function
 * 
 * @param handle vsr process handle.
 * @param input_data input data buffer
 * @param output_data output data buffer
 * @param cb  callback function.
 * @return IVSRStatus 
 */
IVSRStatus ivsr_process(ivsr_handle handle, char* input_data, char* output_data, ivsr_cb_t* cb);

/**
 * @brief reset the configures for vsr
 * 
 * @param handle  vsr process handle
 * @param configs changed configurations for vsr.
 * @return IVSRStatus 
 */
IVSRStatus ivsr_reconfig(ivsr_handle handle, ivsr_config_t* configs);

/**
 * @brief get attributes 
 * 
 * @param handle vsr process handle
 * @param key indicate which type information to query.
 * @param value returned data.
 * @return IVSRStatus 
 */
IVSRStatus ivsr_get_attr(ivsr_handle handle, IVSRAttrKey key, void* value);

/**
 * @brief free created vsr handle and conresponding resources.
 * 
 * @param  handle vsr process handle.
 * @return IVSRStatus 
 */
IVSRStatus ivsr_deinit(ivsr_handle handle);


#ifdef __cplusplus
}
#endif

#endif //I_VSR_API_H