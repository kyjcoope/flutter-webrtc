package org.webrtc.audio;

import android.util.Log;

public class AudioBufferUtil {
    private static final String TAG = "AudioBufferUtil";
    private static final String AUDIO_BUFFER_KEY = "webrtc_audio_output";
    private static boolean initialized = false;

    static {
        System.loadLibrary("native_lib");
    }

    private static native int initNativeBuffer(String key, int capacity, int bufferSize);
    private static native long pushAudioData(String key, byte[] samples, int sampleRate, int channels, long frameTime);
    private static native void freeNativeBuffer(String key);

    public static boolean ensureInitialized(int capacity, int maxBufferSize) {
        if (!initialized) {
            int result = initNativeBuffer(AUDIO_BUFFER_KEY, capacity, maxBufferSize);
            initialized = (result != 0);
        }
        return initialized;
    }

    public static long pushAudioSamples(byte[] samples, int sampleRate, int channels) {
        if (!initialized) {
            return 0;
        }
        return pushAudioData(AUDIO_BUFFER_KEY, samples, sampleRate, channels, System.currentTimeMillis());
    }

    public static void dispose() {
        if (initialized) {
            freeNativeBuffer(AUDIO_BUFFER_KEY);
            initialized = false;
        }
    }
}