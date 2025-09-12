#include <jni.h>
#include "native_buffer_api.h"

extern "C" {

JNIEXPORT jint JNICALL
Java_com_cloudwebrtc_webrtc_record_FrameStreamer_initNativeBuffer(
        JNIEnv* env, jclass, jstring jTrackId, jint capacity, jint bufferSize) {
    const char* key = env->GetStringUTFChars(jTrackId, nullptr);
    if (!key) return 0;
    int result = initNativeBufferFFI(key, capacity, bufferSize);
    env->ReleaseStringUTFChars(jTrackId, key);
    return (jint)result;
}

JNIEXPORT jint JNICALL
Java_com_cloudwebrtc_webrtc_record_FrameStreamer_pushFrame(
        JNIEnv* env, jclass, jstring jTrackId, jobject buffer, jint dataSize,
        jint width, jint height, jlong frameTime,
        jint rotation, jint colorFormat) {
    const char* key = env->GetStringUTFChars(jTrackId, nullptr);
    if (!key) return 0;
    auto* base = reinterpret_cast<uint8_t*>(env->GetDirectBufferAddress(buffer));
    if (!base || dataSize <= 0) {
        env->ReleaseStringUTFChars(jTrackId, key);
        return 0;
    }
    int ok = pushRawVideoFrameFFI(key, base, (size_t)dataSize,
                                  width, height, (uint64_t)frameTime,
                                  rotation, colorFormat);
    env->ReleaseStringUTFChars(jTrackId, key);
    return (jint)ok;
}

JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_record_FrameStreamer_freeNativeBuffer(
        JNIEnv* env, jclass, jstring jTrackId) {
    const char* key = env->GetStringUTFChars(jTrackId, nullptr);
    if (key) {
        freeNativeBufferFFI(key);
        env->ReleaseStringUTFChars(jTrackId, key);
    }
}

} // extern "C"
