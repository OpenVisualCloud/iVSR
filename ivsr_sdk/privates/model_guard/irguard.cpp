// Copyright (C) 2022-2023 Intel Corporation

#include <algorithm>
#include <ctime>
#include <fstream>
#include <functional>
#include <iostream>
#include <regex>
#include <string>
#include <vector>

extern "C" {
#include <zlib.h>
}

#include <irguard.hpp>

#include "sys_conf.hpp"

const int _FIXED_LONG_WIDTH = 4;
const float _DEFAULT_DEFLATE_MUL = 1.2;
const float _DEFAULT_INFLATE_MUL = 32.0;

const std::regex _REGEX_EXPIRATION = std::regex("20\\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])");

/************************************ utils *************************************/

void _null_init_z_stream(z_stream& strm, int n_in_bytes, int n_out_bytes) {
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;

    strm.total_in = n_in_bytes;
    strm.avail_in = n_in_bytes;
    strm.total_out = n_out_bytes;
    strm.avail_out = n_out_bytes;
}

void _ulong_to_fixed_width_bytes(const long val, const std::vector<char>::iterator& it, const int width) {
    long temp_val(val);
    for (int i = width - 1; i > -1; --i) {
        *(it + i) = static_cast<char>(temp_val & 0xFF);
        temp_val >>= 8;
    }
}

unsigned long _fixed_width_bytes_to_ulong(const std::vector<char>::iterator& it, const int width) {
    unsigned long val = 0;
    unsigned long count_mul = 1;
    for (int i = width - 1; i > -1; --i) {
        val += static_cast<unsigned long>(static_cast<unsigned char>(*(it + i))) * count_mul;
        count_mul <<= 8;
    }
    return val;
}

std::size_t _make_concatenated_buffer(const std::vector<char>& xml_buffer,
                                      const std::vector<char>& bin_buffer,
                                      const long expiration,
                                      std::vector<char>& concated_buffer) {
    unsigned long len_xml = static_cast<unsigned long>(xml_buffer.size());

    // safer than memcpy like method, limit max size 4G
    int len_header = 2 * _FIXED_LONG_WIDTH;
    std::vector<char> head_buffer(len_header);
    _ulong_to_fixed_width_bytes(expiration, head_buffer.begin(), _FIXED_LONG_WIDTH);
    _ulong_to_fixed_width_bytes(len_xml, head_buffer.begin() + _FIXED_LONG_WIDTH, _FIXED_LONG_WIDTH);

    concated_buffer.resize(len_header + xml_buffer.size() + bin_buffer.size());

    copy(head_buffer.begin(), head_buffer.end(), concated_buffer.begin());
    copy(xml_buffer.begin(), xml_buffer.end(), concated_buffer.begin() + len_header);
    copy(bin_buffer.begin(), bin_buffer.end(), concated_buffer.begin() + len_header + len_xml);

    return concated_buffer.size();
}

long _date_str_to_seconds(const std::string& date_str) {
    std::tm tm{};

    auto yyyy_str = date_str.substr(0, 4);
    auto mm_str = date_str.substr(4, 2);
    auto dd_str = date_str.substr(6, 2);

    tm.tm_year = std::stoi(yyyy_str) - 1900;
    tm.tm_mon = std::stoi(mm_str) - 1;
    tm.tm_mday = std::stoi(dd_str);

    return std::mktime(&tm);
}

/************************************ wrapped zlib interface *************************************/

int _deflate_buffer(const std::vector<char>& src_buff, std::vector<char>& dst_buff, float deflate_size_mul) {
    unsigned long n_bytes = static_cast<unsigned long>(src_buff.size());
    unsigned long n_max_deflate_bytes = static_cast<unsigned long>(static_cast<float>(n_bytes) * deflate_size_mul);

    // Init z stream
    z_stream strm;
    _null_init_z_stream(strm, n_bytes, n_max_deflate_bytes);

    strm.next_in = reinterpret_cast<unsigned char*>(const_cast<char*>(src_buff.data()));
    std::vector<unsigned char> temp_bytes(n_max_deflate_bytes);
    strm.next_out = temp_bytes.data();

    // Deflate
    if (deflateInit(&strm, Z_BEST_COMPRESSION) == Z_OK) {
        if (deflate(&strm, Z_FINISH) != Z_STREAM_END) {
            return irguard::FAIL_DEFLATE;
        }
    } else {
        return irguard::FAIL_DEFLATE;
    }
    deflateEnd(&strm);

    // copy to result
    unsigned long n_compressed_bytes = static_cast<unsigned long>(strm.total_out);
    dst_buff.resize(n_compressed_bytes);
    copy(temp_bytes.begin(), temp_bytes.begin() + n_compressed_bytes, dst_buff.begin());

    return irguard::OK;
}

int _inflate_buffer(const std::vector<char>& src_buff, std::vector<char>& dst_buff, float inflate_size_mul) {
    unsigned long n_bytes = static_cast<unsigned long>(src_buff.size());
    unsigned long n_max_inflate_bytes = static_cast<unsigned long>(static_cast<float>(n_bytes) * inflate_size_mul);

    // Init z stream
    z_stream strm;
    _null_init_z_stream(strm, n_bytes, n_max_inflate_bytes);

    strm.next_in = reinterpret_cast<unsigned char*>(const_cast<char*>(src_buff.data()));
    std::vector<unsigned char> temp_bytes(n_max_inflate_bytes);
    strm.next_out = temp_bytes.data();

    // Inflate
    if (inflateInit(&strm) == Z_OK) {
        if (inflate(&strm, Z_FINISH) != Z_STREAM_END) {
            return irguard::FAIL;
        }
    } else {
        return irguard::FAIL;
    }
    inflateEnd(&strm);

    // copy to result
    unsigned long n_inflate_bytes = static_cast<unsigned long>(strm.total_out);
    dst_buff.resize(n_inflate_bytes);
    copy(temp_bytes.begin(), temp_bytes.begin() + n_inflate_bytes, dst_buff.begin());

    return irguard::OK;
}

/************************************ main ************************************/

int irguard::pack(const std::vector<char>& xml_buffer,
                  const std::vector<char>& bin_buffer,
                  const std::string& expiration,
                  std::vector<char>& packed_buffer) {
    if (!std::regex_match(expiration, _REGEX_EXPIRATION))
        return FAIL_INVALID_EXPIRATION;

    long expiration_in_secs = _date_str_to_seconds(expiration);

    std::vector<char> concated_buffer;
    _make_concatenated_buffer(xml_buffer, bin_buffer, expiration_in_secs, concated_buffer);
    std::reverse(concated_buffer.begin(), concated_buffer.end());
    int ret = _deflate_buffer(concated_buffer, packed_buffer, _DEFAULT_DEFLATE_MUL);
    std::reverse(packed_buffer.begin(), packed_buffer.end());

    // TODO: fix ignostic errors?
    return ret;
}

long irguard::unpack(const std::vector<char>& packed_buffer,
                     std::vector<char>& xml_buffer,
                     std::vector<char>& bin_buffer) {
    std::vector<char> packed_copy(packed_buffer);
    std::vector<char> inflated_buffer;

    std::reverse(packed_copy.begin(), packed_copy.end());
    if (_inflate_buffer(packed_copy, inflated_buffer, _DEFAULT_INFLATE_MUL) == FAIL)
        return FAIL_INFLATE;

    std::reverse(inflated_buffer.begin(), inflated_buffer.end());
    unsigned long expiration = _fixed_width_bytes_to_ulong(inflated_buffer.begin(), _FIXED_LONG_WIDTH);
    unsigned long len_xml = _fixed_width_bytes_to_ulong(inflated_buffer.begin() + _FIXED_LONG_WIDTH, _FIXED_LONG_WIDTH);
    int len_header = 2 * _FIXED_LONG_WIDTH;

    xml_buffer.assign(inflated_buffer.begin() + len_header, inflated_buffer.begin() + len_header + len_xml);
    bin_buffer.assign(inflated_buffer.begin() + len_header + len_xml, inflated_buffer.end());

    // TODO: fix ignostic errors?
    return expiration;
}

int irguard::load_file_to_buffer(const std::string& filepath, std::vector<char>& buffer) {
    std::ifstream fs(filepath, std::ios::binary | std::ios::ate);
    if (!fs.is_open()) {
        return FAIL;
    }

    std::streamsize fsize = fs.tellg();
    fs.seekg(0, std::ios::beg);
    buffer.resize(fsize);
    fs.read(buffer.data(), fsize);
    fs.close();

    if (!fs.good()) {
        return FAIL;
    }

    return OK;
}

int irguard::write_buffer_to_file(const std::vector<char>& buffer, const std::string& filepath) {
    std::ofstream fs(filepath, std::ios::binary);
    if (!fs.is_open()) {
        return FAIL;
    }
    fs.write(buffer.data(), buffer.size());
    fs.close();

    if (!fs.good()) {
        return FAIL;
    }

    return OK;
}

int irguard::system_conf_check() {
    SystemProperties::Ptr prop_ptr = std::make_shared<SystemProperties>();
    PlatformBroker plat_broker = PlatformBroker(prop_ptr);

    int ret = plat_broker.platform_check();
    if (ret == 0) {
        std::cout << "platform check pass" << std::endl;
        return OK;
    }

    std::cout << "platform check failed!" << std::endl;
    return FAIL;
}
