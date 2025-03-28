package org.webrtc.video;

import androidx.annotation.Nullable;
import org.webrtc.EglBase;
import org.webrtc.SoftwareVideoDecoderFactory;
import org.webrtc.VideoCodecInfo;
import org.webrtc.VideoDecoder;
import org.webrtc.VideoDecoderFactory;
import org.webrtc.WrappedVideoDecoderFactory;
import org.webrtc.video.VideoDecoderBypass;

import java.util.LinkedList;
import java.util.Queue;
import java.util.Map;
import java.util.ArrayList;
import java.util.List;
import android.util.Log;

public class CustomVideoDecoderFactory implements VideoDecoderFactory {
    private static final Queue<String> trackQueue = new LinkedList<>();
    private SoftwareVideoDecoderFactory softwareVideoDecoderFactory = new SoftwareVideoDecoderFactory();
    private WrappedVideoDecoderFactory wrappedVideoDecoderFactory;
    private boolean forceSWCodec = false;
    private List<String> forceSWCodecs = new ArrayList<>();

    public CustomVideoDecoderFactory(EglBase.Context sharedContext) {
        this.wrappedVideoDecoderFactory = new WrappedVideoDecoderFactory(sharedContext);
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
        String trackId;
        synchronized (trackQueue) {
            trackId = trackQueue.poll();
        }
        VideoDecoderBypass decoder = new VideoDecoderBypass(trackId, videoCodecInfo);
        return decoder;
    }

    @Override
    public VideoCodecInfo[] getSupportedCodecs() {
        if (forceSWCodec && forceSWCodecs.isEmpty()) {
            return softwareVideoDecoderFactory.getSupportedCodecs();
        }
        return wrappedVideoDecoderFactory.getSupportedCodecs();
    }

    public static void setTrackId(String trackId) {
        synchronized (trackQueue) {
            trackQueue.add(trackId);
        }
    }
}
