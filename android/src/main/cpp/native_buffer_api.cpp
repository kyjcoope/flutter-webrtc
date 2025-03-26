#include "native_buffer_api.h"
#include "dart_api_dl.h"
#include "NativeBuffer.h"
#include <string>
#include <unordered_map>
#include <pthread.h>

static std::unordered_map<std::string, NativeBuffer*> g_nativeBuffers;
static pthread_mutex_t g_nativeBuffersMutex = PTHREAD_MUTEX_INITIALIZER;

static std::unordered_map<std::string, int64_t> g_dartPorts;
static pthread_mutex_t g_portsMutex = PTHREAD_MUTEX_INITIALIZER;

static bool dart_api_initialized = false;

static unsigned long long handleFramePushResult(NativeBuffer* rb, int res, const std::string& key) {
    unsigned long long result = 0;
    
    if (res == 0) {
        int slot = (rb->writeIndex - 1 + rb->capacity) % rb->capacity;
        result = reinterpret_cast<unsigned long long>(rb->frames[slot]);
        
        // notify Dart about new frame if API is initialized
        if (dart_api_initialized) {
            pthread_mutex_lock(&g_portsMutex);
            auto portIt = g_dartPorts.find(key);
            if (portIt != g_dartPorts.end() && portIt->second > 0) {
                // create a simple notification message
                Dart_CObject message;
                memset(&message, 0, sizeof(Dart_CObject));
                message.type = Dart_CObject_kInt32;
                message.value.as_int32 = 1; // signal that a frame is available
                
                Dart_PostCObject_DL(portIt->second, &message);
            }
            pthread_mutex_unlock(&g_portsMutex);
        }
    }
    
    return result;
}

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
    
    pthread_mutex_lock(&g_nativeBuffersMutex);
    auto it = g_nativeBuffers.find(skey);
    if (it == g_nativeBuffers.end()) {
        pthread_mutex_unlock(&g_nativeBuffersMutex);
        return 0;
    }
    
    NativeBuffer* rb = it->second;
    int res = nativeBufferPush(rb, buffer, dataSize, width, height, frameTime, rotation, frameType);
    unsigned long long result = handleFramePushResult(rb, res, skey);
    
    pthread_mutex_unlock(&g_nativeBuffersMutex);
    return result;
}

FFI_PLUGIN_EXPORT unsigned long long pushAudioNativeBufferFFI(const char* key, const uint8_t* buffer, int dataSize,
    int sampleRate, int channels, uint64_t frameTime) {
    if (!key || !buffer || dataSize <= 0) return 0;
    std::string skey(key);
    
    pthread_mutex_lock(&g_nativeBuffersMutex);
    auto it = g_nativeBuffers.find(skey);
    if (it == g_nativeBuffers.end()) {
        pthread_mutex_unlock(&g_nativeBuffersMutex);
        return 0;
    }
    
    NativeBuffer* rb = it->second;
    int res = nativeBufferPushAudio(rb, buffer, dataSize, sampleRate, channels, frameTime);
    unsigned long long result = handleFramePushResult(rb, res, skey);
    
    pthread_mutex_unlock(&g_nativeBuffersMutex);
    return result;
}

FFI_PLUGIN_EXPORT unsigned long long popNativeBufferFFI(const char* key) {
    if (!key) return 0;
    std::string skey(key);
    auto it = g_nativeBuffers.find(skey);
    if (it == g_nativeBuffers.end()) {
        return 0;
    }
    NativeBuffer* rb = it->second;
    MediaFrame* frame = nativeBufferPop(rb);
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

FFI_PLUGIN_EXPORT bool initializeDartApiDL(void* data) {
    if (dart_api_initialized) {
        return true;
    }
    
    if (data == nullptr) {
        return false;
    }
    
    if (Dart_InitializeApiDL(data) != 0) {
        return false;
    }
    
    dart_api_initialized = true;
    return true;
}

FFI_PLUGIN_EXPORT bool registerDartPort(const char* channel_name, int64_t port) {    
    if (!channel_name || port <= 0) {
        return false;
    }
    
    std::string channel(channel_name);
    
    pthread_mutex_lock(&g_portsMutex);
    g_dartPorts[channel] = port;
    pthread_mutex_unlock(&g_portsMutex);
    return true;
}
