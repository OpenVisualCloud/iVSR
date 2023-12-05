#include <chrono>
#include <fstream>
#include <iostream>

#include <irguard.hpp>
/* Workaround private interface */
#include <irguard_inner.hpp>

void usage(int zip_flag, char** argv) {
    if (zip_flag == 0) {
        std::cout << "Usage[zip]: " << argv[0] << " " << argv[1] << " <input> <output> <expire_date>" << std::endl;
    } else if (zip_flag == 1) {
        std::cout << "Usage[unzip]: " << argv[0] << " " << argv[1] << " <input> <output>" << std::endl;
    } else {
        std::cout << "Usage: " << argv[0] << " -z/--zip <input> <output> <expire_date>" << std::endl;
        std::cout << "       " << argv[0] << " -u/--unzip <input> <output>" << std::endl;
        std::cout << "Example: " << argv[0] << " -z /tmp/resnet /tmp/output/test    20231231" << std::endl;
        std::cout << "         " << argv[0] << " -u /tmp/test   /tmp/output/resnet" << std::endl;
    }
}

int main(int argc, char** argv) {
    // Check command line parameters
    if (argc < 4) {
        usage(-1, argv);
        return EXIT_SUCCESS;
    }
    
    std::string action = argv[1];

    // @input - For zip, input raw file name w/o "xml" or "bin" suffix
    //        - For unzip, input zipped file name
    std::string input = argv[2];

    // @output - For zip, output full path and zipped file name
    //         - For unzip, output path of unzipped file, named as input w/ "bin" & "xml" suffix
    std::string output = argv[3];

    if (action == "-z" || action == "--zip") {
        if (argc != 5) {
            usage(0, argv);
            return EXIT_SUCCESS;
        }

        std::string expire_date = argv[4];

        std::string xml_file = input + ".xml";
        std::string bin_file = input + ".bin";

        std::vector<std::string> zip_files = {xml_file, bin_file};
        std::vector<char> temp_bufs[2];

        std::cout << "Zip IR file: " << xml_file << " and " << bin_file << std::endl;

        for (int i = 0; i < zip_files.size(); i++) {
            std::ifstream file(zip_files[i], std::ios::binary | std::ios::ate);

            if (!file.is_open()) {
                std::cerr << "File: " << zip_files[i] << " cannot be opened." << std::endl;
                return EXIT_FAILURE;
            }

            auto file_size = file.tellg();
            temp_bufs[i].resize(file_size);

            file.seekg(0, std::ios::beg);
            file.read(&temp_bufs[i][0], temp_bufs[i].size());
            file.close();
        }

        std::vector<char> out_buf;
        irguard::pack(temp_bufs[0], temp_bufs[1], expire_date, out_buf);

        irguard::write_buffer_to_file(out_buf, output);

        return EXIT_SUCCESS;
    } else if (action == "-u" || action == "--unzip") {
        if (argc != 4) {
            usage(1, argv);
            return EXIT_SUCCESS;
        }
        std::vector<char> packed_buffer;

        if (irguard::load_file_to_buffer(input, packed_buffer) != irguard::OK) {
            std::cerr << "Failed to load file: " << input << "." << std::endl;
            return EXIT_FAILURE;
        }

        const long SECONDS_SINCE_EPOCH_2023 = 1672531200;
        std::vector<char> xml_buffer, bin_buffer;
        long expiration = irguard::unpack(packed_buffer, xml_buffer, bin_buffer);
        if (expiration > SECONDS_SINCE_EPOCH_2023) {
            std::cout << "[Record] Expiration: " << std::asctime(std::localtime(&expiration)) << std::endl;
        }

        std::string xml_file = output + ".xml";
        if (irguard::write_buffer_to_file(xml_buffer, xml_file) != irguard::OK) {
            std::cerr << "Failed to write xml file: " << xml_file << "." << std::endl;
            return EXIT_FAILURE;
        }

        std::string bin_file = output + ".bin";
        if (irguard::write_buffer_to_file(bin_buffer, bin_file) != irguard::OK) {
            std::cerr << "Failed to write bin file: " << bin_file << "." << std::endl;
            return EXIT_FAILURE;
        }

        return EXIT_SUCCESS;
    }

    usage(-1, argv);
    return EXIT_FAILURE;
}