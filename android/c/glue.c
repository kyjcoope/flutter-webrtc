#include <jni.h>

JNIEXPORT jlong JNICALL Java_org_webrtc_MySuperSecretDecoder_getAddress(JNIEnv *env, jclass clazz, jobject buffer) {
    return (jlong)(*env)->GetDirectBufferAddress(env, buffer);
}