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
#ifndef __IRGUARD_INNER_HPP
#define __IRGUARD_INNER_HPP

#include <string>
#include <vector>

namespace irguard {

int pack(const std::vector<char>& xml_buffer,
         const std::vector<char>& bin_buffer,
         const std::string& expiration,
         std::vector<char>& packed_buffer);

long unpack(const std::vector<char>& packed_buffer, std::vector<char>& xml_buffer, std::vector<char>& bin_buffer);

int load_file_to_buffer(const std::string& filepath, std::vector<char>& buffer);
int write_buffer_to_file(const std::vector<char>& buffer, const std::string& filepath);

int system_conf_check();

const int OK = 0;
const int FAIL = -1;
const int FAIL_INVALID_EXPIRATION = -2;
const int FAIL_INFLATE = -3;
const int FAIL_DEFLATE = -4;

}  // namespace irguard

#endif
