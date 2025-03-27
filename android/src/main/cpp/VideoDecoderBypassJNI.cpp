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
    return result;
}

JNIEXPORT jlong JNICALL
Java_org_webrtc_video_VideoDecoderBypass_pushFrame(JNIEnv *env, jclass clazz, jstring jTrackId, jobject buffer,
                                                      jint width, jint height, jlong frameTime, jint rotation, jint frameType) {
    const char* key = env->GetStringUTFChars(jTrackId, NULL);
    if (!key) return 0;
    uint8_t* buf = reinterpret_cast<uint8_t*>(env->GetDirectBufferAddress(buffer));
    jlong size = env->GetDirectBufferCapacity(buffer);
    uintptr_t result = pushVideoNativeBufferFFI(key, buf, static_cast<size_t>(size),
                                                  width, height, static_cast<uint64_t>(frameTime),
                                                  rotation, frameType);
    env->ReleaseStringUTFChars(jTrackId, key);
    return static_cast<jlong>(result);
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
