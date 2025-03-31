#ifndef NATIVE_BUFFER_API_H
#define NATIVE_BUFFER_API_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#if defined(_WIN32)
  #define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
  #define FFI_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT int initNativeBufferFFI(const char* key, int capacity, int maxBufferSize);
FFI_PLUGIN_EXPORT int pushVideoNativeBufferFFI(const char* key, const uint8_t* buffer, size_t dataSize,
  int width, int height, uint64_t frameTime, int rotation, int frameType, int codecType);
FFI_PLUGIN_EXPORT int pushAudioNativeBufferFFI(const char* key, const uint8_t* buffer, size_t dataSize,
  int sampleRate, int channels, uint64_t frameTime);
FFI_PLUGIN_EXPORT uintptr_t popNativeBufferFFI(const char* key);
FFI_PLUGIN_EXPORT void freeNativeBufferFFI(const char* key);

FFI_PLUGIN_EXPORT bool initializeDartApiDL(void* data);
FFI_PLUGIN_EXPORT bool registerDartPort(const char* channel_name, int64_t port);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // NATIVE_BUFFER_API_H
