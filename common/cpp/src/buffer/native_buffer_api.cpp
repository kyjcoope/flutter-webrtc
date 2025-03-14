#include "buffer/native_buffer_api.h"
#include "buffer/NativeBuffer.h"
#include <string>
#include <unordered_map>

static std::unordered_map<std::string, NativeBuffer*> g_nativeBuffers;

FFI_PLUGIN_EXPORT int initNativeBufferFFI(const char* key, int capacity, int maxBufferSize) {
    if (!key) return 0;
    std::string skey(key);
    if (g_nativeBuffers.find(skey) == g_nativeBuffers.end()) {
        NativeBuffer* rb = nativeBufferInit(capacity, maxBufferSize);
        if (!rb) {
            return 0;
        }
        g_nativeBuffers[skey] = rb;
    }
    return 1;
}

FFI_PLUGIN_EXPORT unsigned long long pushNativeBufferFFI(const char* key, const uint8_t* buffer, int dataSize,
    int width, int height, uint64_t frameTime, int rotation, int frameType) {
    if (!key || !buffer || dataSize <= 0) return 0;
    std::string skey(key);
    auto it = g_nativeBuffers.find(skey);
    if (it == g_nativeBuffers.end()) {
        return 0;
    }
    NativeBuffer* rb = it->second;
    int res = nativeBufferPush(rb, buffer, dataSize, width, height, frameTime, rotation, frameType);
    if (res != 0) {
       return 0;
    }
    int slot = (rb->writeIndex - 1 + rb->capacity) % rb->capacity;
    return reinterpret_cast<unsigned long long>(rb->frames[slot]);
}

FFI_PLUGIN_EXPORT unsigned long long popNativeBufferFFI(const char* key) {
    if (!key) return 0;
    std::string skey(key);
    auto it = g_nativeBuffers.find(skey);
    if (it == g_nativeBuffers.end()) {
        return 0;
    }
    NativeBuffer* rb = it->second;
    EncodedFrame* frame = nativeBufferPop(rb);
    return reinterpret_cast<unsigned long long>(frame);
}

FFI_PLUGIN_EXPORT void freeNativeBufferFFI(const char* key) {
    if (!key) return;
    std::string skey(key);
    auto it = g_nativeBuffers.find(skey);
    if (it != g_nativeBuffers.end()) {
       nativeBufferFree(it->second);
       g_nativeBuffers.erase(it);
    }
}
