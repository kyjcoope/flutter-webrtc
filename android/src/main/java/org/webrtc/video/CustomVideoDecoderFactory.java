package org.webrtc.video;

import androidx.annotation.Nullable;

import org.webrtc.EglBase;
import org.webrtc.SoftwareVideoDecoderFactory;
import org.webrtc.VideoCodecInfo;
import org.webrtc.VideoDecoder;
import org.webrtc.VideoDecoderFactory;
import org.webrtc.WrappedVideoDecoderFactory;
import org.webrtc.MySuperSecretDecoder;


import io.flutter.plugin.common.BinaryMessenger;

import java.util.ArrayList;
import java.util.List;

public class CustomVideoDecoderFactory implements VideoDecoderFactory {
    private SoftwareVideoDecoderFactory softwareVideoDecoderFactory = new SoftwareVideoDecoderFactory();
    private WrappedVideoDecoderFactory wrappedVideoDecoderFactory;
    private boolean forceSWCodec  = false;
    private BinaryMessenger messenger;

    private List<String> forceSWCodecs = new ArrayList<>();

    public  CustomVideoDecoderFactory(EglBase.Context sharedContext, BinaryMessenger messenger) {
        this.wrappedVideoDecoderFactory = new WrappedVideoDecoderFactory(sharedContext);
        this.messenger = messenger;
    }

    public void setForceSWCodec(boolean forceSWCodec) {
        this.forceSWCodec = forceSWCodec;
    }

    public void setForceSWCodecList(List<String> forceSWCodecs) {
        this.forceSWCodecs = forceSWCodecs;
    }

    @Nullable
    @Override
    public VideoDecoder createDecoder(VideoCodecInfo videoCodecInfo) {
        return new MySuperSecretDecoder(this.messenger);
        // if(forceSWCodec) {
        //     return softwareVideoDecoderFactory.createDecoder(videoCodecInfo);
        // }
        // if(!forceSWCodecs.isEmpty()) {
        //     if(forceSWCodecs.contains(videoCodecInfo.name)) {
        //         return softwareVideoDecoderFactory.createDecoder(videoCodecInfo);
        //     }
        // }
        // return wrappedVideoDecoderFactory.createDecoder(videoCodecInfo);
    }

    @Override
    public VideoCodecInfo[] getSupportedCodecs() {
        if(forceSWCodec && forceSWCodecs.isEmpty()) {
            return softwareVideoDecoderFactory.getSupportedCodecs();
        }
        return wrappedVideoDecoderFactory.getSupportedCodecs();
    }
}
