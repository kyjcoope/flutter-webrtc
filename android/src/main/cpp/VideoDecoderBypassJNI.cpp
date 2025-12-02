#include <jni.h>
#include <stdlib.h>
#include <string.h>
#include "native_buffer_api.h"

extern "C" {

JNIEXPORT jint JNICALL
Java_org_webrtc_video_VideoDecoderBypass_initNativeBuffer(JNIEnv *env, jclass clazz, jstring jTrackId, jint capacity, jint bufferSize) {
    const char* key = env->GetStringUTFChars(jTrackId, NULL);
    if (!key) {
        return 0;
    }
    int result = initNativeBufferFFI(key, capacity, bufferSize);
    env->ReleaseStringUTFChars(jTrackId, key);
    return static_cast<jint>(result);
}

JNIEXPORT jlong JNICALL
Java_org_webrtc_video_VideoDecoderBypass_pushFrame(JNIEnv *env, jclass clazz, jstring jTrackId, jobject buffer,
                                                      jint width, jint height, jlong frameTime,
                                                      jint rotation, jint frameType, jint codecType) {
    const char* key = env->GetStringUTFChars(jTrackId, NULL);
    if (!key) {
        return 0LL;
    }
    uint8_t* buf = reinterpret_cast<uint8_t*>(env->GetDirectBufferAddress(buffer));
    if (!buf) {
         env->ReleaseStringUTFChars(jTrackId, key);
         return 0LL;
    }
    jlong capacity = env->GetDirectBufferCapacity(buffer);
    if (capacity <= 0) {
        env->ReleaseStringUTFChars(jTrackId, key);
        return 0LL;
    }
    size_t dataSize = static_cast<size_t>(capacity);
    int ffi_result = pushVideoNativeBufferFFI(key, buf, dataSize,
                                             width, height, static_cast<uint64_t>(frameTime),
                                             rotation, frameType, static_cast<int>(codecType));
    env->ReleaseStringUTFChars(jTrackId, key);
    return static_cast<jlong>(ffi_result);
}

JNIEXPORT void JNICALL
Java_org_webrtc_video_VideoDecoderBypass_freeNativeBuffer(JNIEnv *env, jclass clazz, jstring jTrackId) {
    const char* key = env->GetStringUTFChars(jTrackId, NULL);
    if (key) {
        freeNativeBufferFFI(key);
        env->ReleaseStringUTFChars(jTrackId, key);
    }
}

} // extern "C"
