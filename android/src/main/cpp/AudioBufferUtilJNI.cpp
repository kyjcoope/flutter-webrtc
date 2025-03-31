#include <jni.h>
#include <stdlib.h>
#include <string.h>
#include "native_buffer_api.h"

extern "C" {

JNIEXPORT jint JNICALL
Java_org_webrtc_audio_AudioBufferUtil_initNativeBuffer(JNIEnv *env, jclass clazz, jstring jKey, jint capacity, jint bufferSize) {
    const char* key = env->GetStringUTFChars(jKey, NULL);
    if (!key) {
        return 0;
    }
    int result = initNativeBufferFFI(key, capacity, bufferSize);
    env->ReleaseStringUTFChars(jKey, key);
    return static_cast<jint>(result);
}

JNIEXPORT jlong JNICALL
Java_org_webrtc_audio_AudioBufferUtil_pushAudioData(JNIEnv *env, jclass clazz, jstring jKey,
                                                             jbyteArray samples, jint sampleRate, jint channels, jlong frameTime) {
    const char* key = env->GetStringUTFChars(jKey, NULL);
    if (!key) {
        return 0LL;
    }
    jbyte* byteArray = env->GetByteArrayElements(samples, NULL);
    if (!byteArray) {
        env->ReleaseStringUTFChars(jKey, key);
        return 0LL;
    }
    jsize size = env->GetArrayLength(samples);
    int result = pushAudioNativeBufferFFI(key, reinterpret_cast<uint8_t*>(byteArray), static_cast<size_t>(size),
                                             sampleRate, channels, static_cast<uint64_t>(frameTime));
    env->ReleaseByteArrayElements(samples, byteArray, JNI_ABORT);
    env->ReleaseStringUTFChars(jKey, key);
    return static_cast<jlong>(result);
}

JNIEXPORT void JNICALL
Java_org_webrtc_audio_AudioBufferUtil_freeNativeBuffer(JNIEnv *env, jclass clazz, jstring jKey) {
    const char* key = env->GetStringUTFChars(jKey, NULL);
    if (key) {
        freeNativeBufferFFI(key);
        env->ReleaseStringUTFChars(jKey, key);
    }
}

} // extern "C"
