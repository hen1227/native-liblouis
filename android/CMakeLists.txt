cmake_minimum_required(VERSION 3.18.1)
project("liblouis-jni")

# Add the JNI library
add_library(liblouis-jni SHARED
    src/main/cpp/liblouis-jni.cpp
)

# Find required libraries
find_library(log-lib log)

# Set include directories
target_include_directories(liblouis-jni PRIVATE
    src/main/cpp/include
)

# Link libraries based on architecture
if(${ANDROID_ABI} STREQUAL "arm64-v8a")
    set(LIBLOUIS_STATIC "${CMAKE_CURRENT_SOURCE_DIR}/src/main/jniLibs/arm64-v8a/liblouis.a")
elseif(${ANDROID_ABI} STREQUAL "armeabi-v7a")
    set(LIBLOUIS_STATIC "${CMAKE_CURRENT_SOURCE_DIR}/src/main/jniLibs/armeabi-v7a/liblouis.a")
elseif(${ANDROID_ABI} STREQUAL "x86")
    set(LIBLOUIS_STATIC "${CMAKE_CURRENT_SOURCE_DIR}/src/main/jniLibs/x86/liblouis.a")
elseif(${ANDROID_ABI} STREQUAL "x86_64")
    set(LIBLOUIS_STATIC "${CMAKE_CURRENT_SOURCE_DIR}/src/main/jniLibs/x86_64/liblouis.a")
endif()

# Link against the static liblouis library and Android log library
target_link_libraries(liblouis-jni
    ${LIBLOUIS_STATIC}
    ${log-lib}
)
