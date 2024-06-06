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

#include "sys_conf.hpp"

#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>

#include <sstream>

bool check_mac_address(const char* net_if_name, const uint8_t mac_addr[]) {
    if (net_if_name == nullptr) {
        return false;
    }

    int sock = 0;
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        return false;
    }

    struct ifaddrs *ifaddr, *ifa;
    // Get the interface address list
    if (getifaddrs(&ifaddr) == -1) {
        perror("Failed to get interface address list");
        return false;
    }

    struct ifreq ifreq;
    const std::string if_name{net_if_name};
    // Iterate through each interface
    for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr != NULL && ifa->ifa_addr->sa_family == AF_PACKET) {
            if (if_name != std::string(ifa->ifa_name))
                continue;

            strcpy(ifreq.ifr_name, ifa->ifa_name);
            if (ioctl(sock, SIOCGIFHWADDR, &ifreq) < 0) {
                break;
            }

            // Get the MAC address
            if (ioctl(sock, SIOCGIFHWADDR, &ifreq) < 0) {
                break;
            }

            // Extract and print the MAC address
            unsigned char* mac = (unsigned char*)ifreq.ifr_hwaddr.sa_data;
            // printf("MAC address: %02X:%02X:%02X:%02X:%02X:%02X\n",
            //       mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

            if (mac[0] == mac_addr[0] && mac[1] == mac_addr[1] && mac[2] == mac_addr[2] && mac[3] == mac_addr[3] &&
                mac[4] == mac_addr[4] && mac[5] == mac_addr[5]) {
                freeifaddrs(ifaddr);
                close(sock);
                return true;
            }
        }
    }

    freeifaddrs(ifaddr);  // Free the interface address list
    close(sock);          // Close the socket
    return false;
}

void split_mac_address(const std::string& macAddress, uint8_t* macArray) {
    std::istringstream iss(macAddress);
    std::string token;
    int i = 0;

    while (std::getline(iss, token, ':')) {
        std::stringstream ss;
        ss << std::hex << token;
        int value;
        ss >> value;
        macArray[i++] = static_cast<uint8_t>(value);
    }
}

static const char intel[] = "ntel";
static const char amd[] = "cAMD";

unsigned int get32bitAsBE(const char* x) {
    return x[0] | (x[1] << 8) | (x[2] << 16) | (x[3] << 24);
}

void cpuid(unsigned int* eax, unsigned int* ebx, unsigned int* ecx, unsigned int* edx) {
    __asm__ __volatile__("cpuid;" : "=a"(*eax), "=b"(*ebx), "=c"(*ecx), "=d"(*edx) : "a"(*eax));
}

bool check_cpuid() {
    unsigned int eax, ebx, ecx, edx;

    // Initialize EAX with the function number you want (e.g., 0 for CPU vendor string)
    eax = 0;
    cpuid(&eax, &ebx, &ecx, &edx);

    if (get32bitAsBE(intel) == ecx)
        return true;

    return false;
}

namespace irguard {

int PlatformBroker::platform_check() {
    if (mSystemProperties.get() == nullptr) {
        return 0;
    }

    if (mSystemProperties->get_property(SYS_PROPERTY::MAC_ADDR_BINDING)) {
        // std::cout << "mac address checking" << std::endl;
        uint8_t mac_address[6]{};
        split_mac_address(STR2(BIND_MAC_ADDR), mac_address);
        if (!check_mac_address(STR2(BIND_NET_NAME), mac_address))
            return -1;
    }

    if (mSystemProperties->get_property(SYS_PROPERTY::X86_PLATFORM_BINDING)) {
        // std::cout << "cpu id checking" << std::endl;
        if (!check_cpuid())
            return -1;
    }

    return 0;
}

}  // namespace irguard
