set(TARGET_NAME "ir_zip")

file(GLOB SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)

file(GLOB HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/*.hpp)

add_executable(${TARGET_NAME} ${SOURCES} ${HEADERS})

target_include_directories(${TARGET_NAME} PUBLIC ${SDK_PRIVATE_HEADERS})
target_include_directories(${TARGET_NAME} PUBLIC ${SDK_PRIVATE_HEADERS}/../model_guard)

find_package(OpenVINO REQUIRED COMPONENTS Runtime)
if (REBUILD_IRGUARD)
    target_link_libraries(${TARGET_NAME} PRIVATE irguard z)
else()
    target_link_libraries(${TARGET_NAME} PRIVATE ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libirguard.a z)
endif()
target_link_libraries(${TARGET_NAME} PRIVATE openvino::runtime)
