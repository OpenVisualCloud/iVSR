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

#ifndef _SYS_CONF_HPP_
#define _SYS_CONF_HPP_

#include <unistd.h>

#include <iostream>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace irguard {

enum class SYS_PROPERTY {
    MAC_ADDR_BINDING = 0,
    X86_PLATFORM_BINDING = 1,
};

#define STR1(R) #R
#define STR2(R) STR1(R)

class SystemProperties {
public:
    using Ptr = std::shared_ptr<SystemProperties>;

    void set_property(SYS_PROPERTY property, bool enable) {
        mProperties[sys_property_to_string(property)] = enable;
    }

    bool get_property(SYS_PROPERTY property) {
        return mProperties[sys_property_to_string(property)];
    }

    // debugging function
    static void print_bind_mac_addr() {
        std::cout << STR2(BIND_NET_NAME) << std::endl;
        std::cout << STR2(BIND_MAC_ADDR) << std::endl;
    }

private:
    std::string sys_property_to_string(SYS_PROPERTY property) {
        switch (property) {
        case SYS_PROPERTY::MAC_ADDR_BINDING:
            return "mac_addr_binding";
        case SYS_PROPERTY::X86_PLATFORM_BINDING:
            return "x86_platform_binding";
        default:
            return "unknown";
        }
    }

    std::map<std::string, bool> mProperties;
};

class PlatformBroker {
public:
    explicit PlatformBroker(SystemProperties::Ptr sys_prop_ptr) : mSystemProperties(sys_prop_ptr) {
#if defined(BIND_NET_NAME) && defined(BIND_MAC_ADDR)
        mSystemProperties->set_property(SYS_PROPERTY::MAC_ADDR_BINDING, true);
#else
        mSystemProperties->set_property(SYS_PROPERTY::MAC_ADDR_BINDING, false);
#endif

#ifdef ENABLE_CPU_ID_CHECK
        mSystemProperties->set_property(SYS_PROPERTY::X86_PLATFORM_BINDING, true);
#else
        mSystemProperties->set_property(SYS_PROPERTY::X86_PLATFORM_BINDING, false);
#endif
    }

    int platform_check();

private:
    SystemProperties::Ptr mSystemProperties;
};

}  // namespace irguard

#endif
