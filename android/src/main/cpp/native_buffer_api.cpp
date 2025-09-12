#include "native_buffer_api.h"
#include "dart_api_dl.h"
#include "NativeBuffer.h"
#include <string>
#include <unordered_map>
#include <mutex>
#include <memory>
#include <atomic>

static std::unordered_map<std::string, std::unique_ptr<NativeBuffer>> g_buffers;
static std::mutex g_buffers_mutex;

static std::unordered_map<std::string, int64_t> g_dartPorts;
static std::mutex g_ports_mutex;

static std::atomic<bool> g_dartApiInitialized{false};

static void notifyDart(const std::string& key) {
    if (!g_dartApiInitialized.load(std::memory_order_acquire)) return;
    int64_t port_id = 0;
    {
        std::lock_guard<std::mutex> lock(g_ports_mutex);
        auto it = g_dartPorts.find(key);
        if (it != g_dartPorts.end()) port_id = it->second;
    }
    if (port_id > 0) {
        Dart_CObject msg;
        msg.type = Dart_CObject_kInt64;
        msg.value.as_int64 = 1;
        Dart_PostCObject_DL(port_id, &msg);
    }
}

static int handlePushResult(int push_result, const std::string& key) {
    if (push_result == 0) {
        notifyDart(key);
        return 1;
    }
    return 0;
}

FFI_PLUGIN_EXPORT int initNativeBufferFFI(const char* key, int capacity, int maxFrameSize) {
    if (!key || capacity <= 0 || maxFrameSize <= 0) return 0;
    std::string sk(key);
    std::lock_guard<std::mutex> lock(g_buffers_mutex);
    if (g_buffers.find(sk) == g_buffers.end()) {
        try {
            g_buffers[sk] = std::make_unique<NativeBuffer>(capacity, maxFrameSize);
        } catch (...) {
            return 0;
        }
    }
    return 1;
}

FFI_PLUGIN_EXPORT int pushRawVideoFrameFFI(const char* key, const uint8_t* buffer, size_t dataSize,
                                           int width, int height, uint64_t frameTimeMs,
                                           int rotation, int colorFormat) {
    if (!key || !buffer || dataSize == 0) return 0;
    std::string sk(key);
    NativeBuffer* target = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_buffers_mutex);
        auto it = g_buffers.find(sk);
        if (it == g_buffers.end()) return 0;
        target = it->second.get();
    }
    int r = target->pushVideoFrame(buffer, dataSize, width, height, frameTimeMs, rotation, colorFormat);
    return handlePushResult(r, sk);
}

FFI_PLUGIN_EXPORT uintptr_t popNativeBufferFFI(const char* key) {
    if (!key) return 0;
    std::string sk(key);
    NativeBuffer* target = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_buffers_mutex);
        auto it = g_buffers.find(sk);
        if (it == g_buffers.end()) return 0;
        target = it->second.get();
    }
    MediaFrame* frame = target->popFrame();
    return reinterpret_cast<uintptr_t>(frame);
}

FFI_PLUGIN_EXPORT void freeNativeBufferFFI(const char* key) {
    if (!key) return;
    std::string sk(key);
    {
        std::lock_guard<std::mutex> lock(g_buffers_mutex);
        g_buffers.erase(sk);
    }
    {
        std::lock_guard<std::mutex> lock2(g_ports_mutex);
        g_dartPorts.erase(sk);
    }
}

FFI_PLUGIN_EXPORT bool initializeDartApiDL(void* data) {
    if (g_dartApiInitialized.load(std::memory_order_relaxed)) return true;
    if (!data) return false;
    if (Dart_InitializeApiDL(data) != 0) return false;
    g_dartApiInitialized.store(true, std::memory_order_release);
    return true;
}

FFI_PLUGIN_EXPORT bool registerDartPort(const char* channel_name, int64_t port) {
    if (!channel_name || port <= 0) return false;
    std::string ch(channel_name);
    {
        std::lock_guard<std::mutex> lock(g_ports_mutex);
        g_dartPorts[ch] = port;
    }
    return true;
}
