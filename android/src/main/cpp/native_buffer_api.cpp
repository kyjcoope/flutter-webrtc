#include "native_buffer_api.h"
#include "dart_api_dl.h"
#include "NativeBuffer.h"
#include <string>
#include <unordered_map>
#include <mutex>
#include <cstdint>
#include <memory>
#include <atomic>

static std::unordered_map<std::string, std::unique_ptr<NativeBuffer>> g_nativeBuffers;
static std::mutex g_nativeBuffersMutex;

static std::unordered_map<std::string, int64_t> g_dartPorts;
static std::mutex g_portsMutex;

static std::atomic<bool> g_dartApiInitialized{false};

static void notifyDartFrameReady(const std::string& key) {
    if (!g_dartApiInitialized.load()) return;
    std::lock_guard<std::mutex> lock(g_portsMutex);
    auto port_it = g_dartPorts.find(key);
    if (port_it != g_dartPorts.end() && port_it->second > 0) {
        Dart_CObject message;
        message.type = Dart_CObject_kInt64;
        message.value.as_int64 = 1;
        Dart_PostCObject_DL(port_it->second, &message);
    }
}

FFI_PLUGIN_EXPORT int initNativeBufferFFI(const char* key, int capacity, int maxBufferSize) {
    if (!key || capacity <= 0 || maxBufferSize <= 0) return 0;
    std::string skey(key);
    std::lock_guard<std::mutex> lock(g_nativeBuffersMutex);
    if (g_nativeBuffers.find(skey) == g_nativeBuffers.end()) {
        try {
            g_nativeBuffers[skey] = std::make_unique<NativeBuffer>(capacity, maxBufferSize);
        } catch (const std::exception& e) {
            return 0;
        }
    }
    return 1;
}

static uintptr_t handlePushResult(int push_result, NativeBuffer* buffer_ptr, const std::string& key) {
    if (push_result == 0) {
        notifyDartFrameReady(key);
        MediaFrame* frame_ptr = buffer_ptr->getLastPushedFrame();
        return reinterpret_cast<uintptr_t>(frame_ptr);
    } else {
        return 0;
    }
}

FFI_PLUGIN_EXPORT uintptr_t pushVideoNativeBufferFFI(const char* key, const uint8_t* buffer, size_t dataSize,
  int width, int height, uint64_t frameTime, int rotation, int frameType) {
    if (!key || !buffer || dataSize == 0) return 0;
    std::string skey(key);
    NativeBuffer* buffer_ptr = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_nativeBuffersMutex);
        auto it = g_nativeBuffers.find(skey);
        if (it == g_nativeBuffers.end()) {
            return 0;
        }
        buffer_ptr = it->second.get();
    } 
    int result = buffer_ptr->pushVideoFrame(buffer, dataSize, width, height, frameTime, rotation, frameType);
    return handlePushResult(result, buffer_ptr, skey);
}

FFI_PLUGIN_EXPORT uintptr_t pushAudioNativeBufferFFI(const char* key, const uint8_t* buffer, size_t dataSize,
  int sampleRate, int channels, uint64_t frameTime) {
     if (!key || !buffer || dataSize == 0) return 0;
    std::string skey(key);
    NativeBuffer* buffer_ptr = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_nativeBuffersMutex);
        auto it = g_nativeBuffers.find(skey);
        if (it == g_nativeBuffers.end()) {
            return 0;
        }
        buffer_ptr = it->second.get();
    }
    int result = buffer_ptr->pushAudioFrame(buffer, dataSize, sampleRate, channels, frameTime);
    return handlePushResult(result, buffer_ptr, skey);
}


FFI_PLUGIN_EXPORT uintptr_t popNativeBufferFFI(const char* key) {
    if (!key) return 0;
    std::string skey(key);
    NativeBuffer* buffer_ptr = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_nativeBuffersMutex);
        auto it = g_nativeBuffers.find(skey);
        if (it == g_nativeBuffers.end()) {
            return 0;
        }
         buffer_ptr = it->second.get();
    }
    MediaFrame* frame = buffer_ptr->popFrame();
    return reinterpret_cast<uintptr_t>(frame);
}

FFI_PLUGIN_EXPORT void freeNativeBufferFFI(const char* key) {
    if (!key) return;
    std::string skey(key);
    std::lock_guard<std::mutex> lock(g_nativeBuffersMutex);
    g_nativeBuffers.erase(skey);

    std::lock_guard<std::mutex> port_lock(g_portsMutex);
    g_dartPorts.erase(skey);
}

FFI_PLUGIN_EXPORT bool initializeDartApiDL(void* data) {
    if (g_dartApiInitialized.load()) {
        return true;
    }
    if (data == nullptr || Dart_InitializeApiDL(data) != 0) {
        return false;
    }
    g_dartApiInitialized.store(true);
    return true;
}

FFI_PLUGIN_EXPORT bool registerDartPort(const char* channel_name, int64_t port) {
    if (!channel_name || port <= 0) {
        return false;
    }
    std::string channel(channel_name);
    std::lock_guard<std::mutex> lock(g_portsMutex);
    g_dartPorts[channel] = port;
    return true;
}
