package org.webrtc.video;

import androidx.annotation.Nullable;

import org.webrtc.EglBase;
import org.webrtc.SoftwareVideoDecoderFactory;
import org.webrtc.VideoCodecInfo;
import org.webrtc.VideoDecoder;
import org.webrtc.VideoDecoderFactory;
import org.webrtc.WrappedVideoDecoderFactory;

import java.util.LinkedList;
import java.util.Queue;
import java.util.Map;
import java.util.ArrayList;
import java.util.List;
import android.util.Log;

public class CustomVideoDecoderFactory implements VideoDecoderFactory {
  private static final String TAG = "CustomVideoDecoderFactory";

  // FIFO of trackIds that should be wired to the next created decoder.
  private static final Queue<String> trackQueue = new LinkedList<>();

  private final SoftwareVideoDecoderFactory softwareVideoDecoderFactory =
          new SoftwareVideoDecoderFactory();
  private final WrappedVideoDecoderFactory wrappedVideoDecoderFactory;

  // Global “force software” options coming from Dart side.
  private boolean forceSWCodec = false;
  private List<String> forceSWCodecs = new ArrayList<>();

  public CustomVideoDecoderFactory(EglBase.Context sharedContext) {
    this.wrappedVideoDecoderFactory = new WrappedVideoDecoderFactory(sharedContext);
  }

  public void setForceSWCodec(boolean forceSWCodec) {
    this.forceSWCodec = forceSWCodec;
  }

  public void setForceSWCodecList(List<String> forceSWCodecs) {
    // Store upper-case names to make comparison simpler/robust.
    this.forceSWCodecs = new ArrayList<>();
    if (forceSWCodecs != null) {
      for (String name : forceSWCodecs) {
        if (name != null) {
          this.forceSWCodecs.add(name.toUpperCase());
        }
      }
    }
  }

  private boolean shouldForceSoftware(VideoCodecInfo codecInfo) {
    if (codecInfo == null || codecInfo.name == null) {
      return forceSWCodec;
    }

    String name = codecInfo.name.toUpperCase();

    // If global “force software” is enabled, always use SW decoder.
    if (forceSWCodec && (forceSWCodecs == null || forceSWCodecs.isEmpty())) {
      return true;
    }

    // If a codec list is specified, force SW only for matching codecs.
    if (forceSWCodecs != null && !forceSWCodecs.isEmpty()) {
      for (String forced : forceSWCodecs) {
        if (name.contains(forced)) {
          return true;
        }
      }
    }

    return false;
  }

  @Nullable
  @Override
  public VideoDecoder createDecoder(VideoCodecInfo videoCodecInfo) {
    // 1) Respect force-software settings first.
    if (shouldForceSoftware(videoCodecInfo)) {
      Log.d(TAG, "createDecoder: using SoftwareVideoDecoderFactory for codec: "
              + (videoCodecInfo != null ? videoCodecInfo.name : "null"));
      return softwareVideoDecoderFactory.createDecoder(videoCodecInfo);
    }

    // 2.5) Try to find "x-track-id" in the codec params (robust method).
    // This is injected by our SDP modifier or passed via custom signaling.
    String trackId = null;
    if (videoCodecInfo != null && videoCodecInfo.params != null) {
      if (videoCodecInfo.params.containsKey("x-track-id")) {
         trackId = videoCodecInfo.params.get("x-track-id");
         Log.d(TAG, "createDecoder: found x-track-id in params: " + trackId);
      }
    }

    // 3) If not in params, fallback to the queue (legacy/race-prone method).
    if (trackId == null) {
      synchronized (trackQueue) {
        trackId = trackQueue.poll();
      }
    }

    // If we don’t have a trackId queued, fall back to normal decoder.
    if (trackId == null) {
      Log.w(TAG, "createDecoder: no trackId found in params or queue, falling back to wrapped decoder. codec="
              + (videoCodecInfo != null ? videoCodecInfo.name : "null"));
      return wrappedVideoDecoderFactory.createDecoder(videoCodecInfo);
    }

    Log.d(TAG, "createDecoder: using VideoDecoderBypass for trackId=" + trackId
            + ", codec=" + (videoCodecInfo != null ? videoCodecInfo.name : "null"));

    // 4) Use bypass decoder when we have a trackId.
    return new VideoDecoderBypass(trackId, videoCodecInfo);
  }

  @Override
  public VideoCodecInfo[] getSupportedCodecs() {
    // For signalling we can just expose the same codecs as the wrapped factory.
    // The actual implementation used at runtime is selected in createDecoder().
    return wrappedVideoDecoderFactory.getSupportedCodecs();
  }

  // Called from PeerConnectionObserver when a remote VideoTrack is created.
  public static void setTrackId(String trackId) {
    if (trackId == null) {
      return;
    }
    synchronized (trackQueue) {
      trackQueue.add(trackId);
    }
  }
}
