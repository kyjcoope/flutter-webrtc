cmake_minimum_required(VERSION 3.31.0)

project(native_lib C CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_C_STANDARD_REQUIRED true)

add_library(native_lib SHARED
    ${CMAKE_SOURCE_DIR}/src/main/cpp/NativeBuffer.cpp
    ${CMAKE_SOURCE_DIR}/src/main/cpp/native_buffer_api.cpp
    ${CMAKE_SOURCE_DIR}/src/main/cpp/VideoDecoderBypassJNI.cpp
    ${CMAKE_SOURCE_DIR}/src/main/cpp/AudioBufferUtilJNI.cpp
    ${CMAKE_SOURCE_DIR}/src/main/cpp/dart_api_dl.c
)

find_library(log-lib log)
find_library(android-lib android)
find_library(opensles-lib OpenSLES)
find_package(JNI REQUIRED)

target_include_directories(native_lib PRIVATE 
    ${JNI_INCLUDE_DIRS} 
    ${CMAKE_SOURCE_DIR}/src/main/cpp
)

target_compile_definitions(native_lib PRIVATE 
    DART_API_DL_IMPLEMENTATION
)

target_link_libraries(native_lib PRIVATE ${log-lib} ${android-lib} ${opensles-lib} ${JNI_LIBRARIES})

set_target_properties(native_lib PROPERTIES LINKER_LANGUAGE CXX)