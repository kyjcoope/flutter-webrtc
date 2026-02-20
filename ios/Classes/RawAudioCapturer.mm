#import "RawAudioCapturer.h"
#import "RTCAudioSource+Private.h"
#include "media_stream_interface.h"
#include "native_buffer_api.h"

static const int kAudioBufferCapacity =
    64;  // More frames than video since audio arrives more frequently

// Forward declaration for the C callback
static void RawAudioCaptureCallback(void* object,
                                    const void* audio_data,
                                    int bits_per_sample,
                                    int sample_rate,
                                    size_t number_of_channels,
                                    size_t number_of_frames);

#pragma mark - C++ Audio Sink Bridge

class RawAudioSinkBridge : public webrtc::AudioTrackSinkInterface {
 private:
  void* _owner;

 public:
  RawAudioSinkBridge(void* owner) : _owner(owner) {}

  void OnData(const void* audio_data,
              int bits_per_sample,
              int sample_rate,
              size_t number_of_channels,
              size_t number_of_frames) override {
    RawAudioCaptureCallback(_owner, audio_data, bits_per_sample, sample_rate, number_of_channels,
                            number_of_frames);
  }

  int NumPreferredChannels() const override { return -1; }
};

#pragma mark - RawAudioCapturer

@implementation RawAudioCapturer {
  __weak RTC_OBJC_TYPE(RTCAudioTrack) * _audioTrack;
  NSString* _trackId;
  BOOL _capturing;
  BOOL _nativeBufferInitialized;
  RawAudioSinkBridge* _bridge;
  webrtc::AudioSourceInterface* _audioSource;
}

- (instancetype)initWithTrack:(RTC_OBJC_TYPE(RTCAudioTrack) *)audioTrack {
  self = [super init];
  if (self) {
    _audioTrack = audioTrack;
    _trackId = audioTrack.trackId;
    _capturing = NO;
    _nativeBufferInitialized = NO;
    _bridge = nullptr;
    _audioSource = nullptr;
  }
  return self;
}

- (NSString*)trackId {
  return _trackId;
}

- (BOOL)isCapturing {
  return _capturing;
}

- (void)startCapture {
  if (_capturing)
    return;

  RTC_OBJC_TYPE(RTCAudioTrack)* track = _audioTrack;
  if (!track) {
    NSLog(@"RawAudioCapturer: Cannot start - track is nil");
    return;
  }

  // Get the native audio source and attach our sink
  rtc::scoped_refptr<webrtc::AudioSourceInterface> audioSourcePtr = track.source.nativeAudioSource;
  _audioSource = audioSourcePtr.get();
  if (!_audioSource) {
    NSLog(@"RawAudioCapturer: Cannot start - audio source is nil");
    return;
  }

  _bridge = new RawAudioSinkBridge((void*)CFBridgingRetain(self));
  _audioSource->AddSink(_bridge);
  _capturing = YES;
  NSLog(@"RawAudioCapturer: Started capture for track %@", _trackId);
}

- (void)stopCapture {
  if (!_capturing)
    return;

  if (_audioSource && _bridge) {
    _audioSource->RemoveSink(_bridge);
    delete _bridge;
    _bridge = nullptr;
  }
  _audioSource = nullptr;
  _capturing = NO;

  if (_nativeBufferInitialized) {
    freeNativeBufferFFI([_trackId UTF8String]);
    _nativeBufferInitialized = NO;
  }

  NSLog(@"RawAudioCapturer: Stopped capture for track %@", _trackId);
}

- (void)dealloc {
  if (_capturing) {
    [self stopCapture];
  }
}

- (void)handleAudioData:(const void*)audioData
          bitsPerSample:(int)bitsPerSample
             sampleRate:(int)sampleRate
               channels:(size_t)channels
                 frames:(size_t)frames {
  if (!_capturing)
    return;

  size_t bytesPerSample = bitsPerSample / 8;
  size_t dataSize = bytesPerSample * channels * frames;

  if (dataSize == 0)
    return;

  // Initialize native buffer on first audio frame
  if (!_nativeBufferInitialized) {
    // Audio buffer size: use a reasonable max.  Typical WebRTC audio is
    // 10ms frames at 48kHz stereo 16-bit = 1920 bytes.
    // Allow up to 4x that for safety.
    int maxBufferSize = (int)(bytesPerSample * channels * sampleRate / 10);  // ~100ms worth
    if (maxBufferSize < (int)dataSize) {
      maxBufferSize = (int)dataSize * 4;
    }

    int result = initNativeBufferFFI([_trackId UTF8String], kAudioBufferCapacity, maxBufferSize);
    if (result == 0) {
      NSLog(@"RawAudioCapturer: Failed to init native buffer for track %@", _trackId);
      return;
    }
    _nativeBufferInitialized = YES;
    NSLog(@"RawAudioCapturer: Initialized buffer for track %@ (rate=%d, ch=%zu, bps=%d)", _trackId,
          sampleRate, channels, bitsPerSample);
  }

  // Push raw PCM into the ring buffer
  uint64_t frameTimeMs = 0;  // WebRTC audio OnData doesn't provide absolute timestamps
  pushAudioNativeBufferFFI([_trackId UTF8String], (const uint8_t*)audioData, dataSize, sampleRate,
                           (int)channels, frameTimeMs);
}

@end

#pragma mark - C Callback

static void RawAudioCaptureCallback(void* object,
                                    const void* audio_data,
                                    int bits_per_sample,
                                    int sample_rate,
                                    size_t number_of_channels,
                                    size_t number_of_frames) {
  @autoreleasepool {
    RawAudioCapturer* capturer = (__bridge RawAudioCapturer*)object;
    [capturer handleAudioData:audio_data
                bitsPerSample:bits_per_sample
                   sampleRate:sample_rate
                     channels:number_of_channels
                       frames:number_of_frames];
  }
}
