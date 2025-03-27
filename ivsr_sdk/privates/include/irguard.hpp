/* Copyright (C) 2025 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __IRGUARD_HPP
#define __IRGUARD_HPP

#include <string>
#include <vector>
#include <openvino/openvino.hpp>

namespace irguard {

std::shared_ptr<ov::Model> load_model(const ov::Core& ins, const std::string path);

}  // namespace irguard

#endif
