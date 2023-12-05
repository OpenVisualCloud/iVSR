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
