package com.cloudwebrtc.webrtc;

import org.webrtc.PeerConnectionFactory;
import org.webrtc.PeerConnectionFactory.Options;
import org.webrtc.EglBase;
import org.webrtc.audio.AudioDeviceModule;
import org.webrtc.video.CustomVideoDecoderFactory;
import org.webrtc.video.CustomVideoEncoderFactory;

import com.cloudwebrtc.webrtc.audio.AudioProcessingController;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class PcFactoryManager {

    private final Map<String, PeerConnectionFactory> factories = new HashMap<>();

    private final AudioDeviceModule audioDeviceModule;
    private final AudioProcessingController audioProcessingController;
    private final EglBase.Context eglContext;
    private final int networkIgnoreMask;
    private final boolean forceSWCodec;
    private final List<String> forceSWCodecList;

    PcFactoryManager(AudioDeviceModule audioDeviceModule,
                     AudioProcessingController audioProcessingController,
                     EglBase.Context eglContext,
                     int networkIgnoreMask,
                     boolean forceSWCodec,
                     List<String> forceSWCodecList) {
        this.audioDeviceModule = audioDeviceModule;
        this.audioProcessingController = audioProcessingController;
        this.eglContext = eglContext;
        this.networkIgnoreMask = networkIgnoreMask;
        this.forceSWCodec = forceSWCodec;
        this.forceSWCodecList = new ArrayList<>(forceSWCodecList);
    }

    synchronized PeerConnectionFactory getDefaultFactory() {
        return getOrCreateFactory("__default__");
    }

    synchronized PeerConnectionFactory getOrCreateFactory(String peerConnectionId) {
        PeerConnectionFactory existing = factories.get(peerConnectionId);
        if (existing != null) {
            return existing;
        }

        Options options = new Options();
        options.networkIgnoreMask = networkIgnoreMask;

        PeerConnectionFactory.Builder factoryBuilder = PeerConnectionFactory.builder()
                .setOptions(options)
                .setAudioDeviceModule(audioDeviceModule)
                .setAudioProcessingFactory(audioProcessingController.externalAudioProcessingFactory);

        CustomVideoEncoderFactory encoderFactory =
                new CustomVideoEncoderFactory(eglContext, true, true);
        CustomVideoDecoderFactory decoderFactory =
                new CustomVideoDecoderFactory(eglContext);

        encoderFactory.setForceSWCodec(forceSWCodec);
        encoderFactory.setForceSWCodecList(forceSWCodecList);
        decoderFactory.setForceSWCodec(forceSWCodec);
        decoderFactory.setForceSWCodecList(forceSWCodecList);

        factoryBuilder
                .setVideoEncoderFactory(encoderFactory)
                .setVideoDecoderFactory(decoderFactory);

        PeerConnectionFactory factory = factoryBuilder.createPeerConnectionFactory();
        factories.put(peerConnectionId, factory);
        return factory;
    }

    synchronized void disposeFactory(String peerConnectionId) {
        PeerConnectionFactory factory = factories.remove(peerConnectionId);
        if (factory != null) {
            factory.dispose();
        }
    }

    synchronized void disposeAll() {
        for (PeerConnectionFactory factory : factories.values()) {
            factory.dispose();
        }
        factories.clear();
    }
}
