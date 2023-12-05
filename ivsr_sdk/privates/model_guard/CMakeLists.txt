set(TARGET_NAME "irguard")

file(GLOB SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)
file(GLOB HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/*.hpp)

add_library(${TARGET_NAME} STATIC ${SOURCES} ${HEADERS})

#set_target_properties(
#  ${TARGET_NAME}
#  PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
#             LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
#             ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
#             PDB_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

# Options
option(ENABLE_MAC_ADDR_CHECK "Enables mac address checking" OFF)
option(ENABLE_CPU_ID_CHECK "Enables cpu id checking" OFF)

if(${ENABLE_MAC_ADDR_CHECK})
    add_definitions(-DENABLE_MAC_ADDR_CHECK)
    add_definitions(-DBIND_NET_NAME=${TARGET_NET_IF})
    add_definitions(-DBIND_MAC_ADDR=${TARGET_MAC_ADDR})
    message(info " ${TARGET_NET_IF}")
    message(info " ${TARGET_MAC_ADDR}")
endif()

if(${ENABLE_CPU_ID_CHECK})
    add_definitions(-DENABLE_CPU_ID_CHECK)
    message(info " CPU ID checking enabled")
endif()

target_include_directories(${TARGET_NAME} PUBLIC ${SDK_PRIVATE_HEADERS})

target_compile_options(${TARGET_NAME} PRIVATE -Wall -Wextra -fPIC)

find_package(OpenVINO REQUIRED COMPONENTS Runtime)
target_link_libraries(${TARGET_NAME} PRIVATE openvino::runtime z)

add_custom_command(
    TARGET ${TARGET_NAME}
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libirguard.a
            ${CMAKE_CURRENT_SOURCE_DIR}/../model_guard.bin
    POST_BUILD)
