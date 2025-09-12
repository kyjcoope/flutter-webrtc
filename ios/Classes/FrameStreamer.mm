#import "FrameStreamer.h"
#import "native_buffer_api.h"
#import <WebRTC/WebRTC.h>

static const int kDefaultCapacity = 16;
static const int kColorFormatI420 = 1;

@interface FrameStreamer ()
@property(nonatomic, strong) RTCVideoTrack *track;
@property(nonatomic, strong) NSString *trackId;
@property(nonatomic, assign) BOOL nativeInited;
@property(nonatomic, assign) int lastWidth;
@property(nonatomic, assign) int lastHeight;
@property(nonatomic, strong) NSMutableData *packingBuffer;
@end

@implementation FrameStreamer

- (instancetype)initWithTrack:(RTCVideoTrack *)track {
  self = [super init];
  if (self) {
    _track = track;
    _trackId = track.trackId ?: @"";
    _nativeInited = NO;
    _lastWidth = 0;
    _lastHeight = 0;
    _packingBuffer = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
      [self.track addRenderer:self];
      NSLog(@"[FrameStreamer] Started for track: %@", self.trackId);
    });
  }
  return self;
}

- (void)stop {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.track) {
      [self.track removeRenderer:self];
    }
  });

  if (_nativeInited) {
    freeNativeBufferFFI(self.trackId.UTF8String);
    _nativeInited = NO;
  }
  _packingBuffer = nil;
  NSLog(@"[FrameStreamer] Stopped for track: %@", self.trackId);
}

- (void)setSize:(CGSize)size {
  // No-op for this sink
}

- (void)renderFrame:(RTC_OBJC_TYPE(RTCVideoFrame) *)frame {
  if (!frame) return;

  id<RTCI420Buffer> i420 = [[frame buffer] toI420];
  if (!i420) return;

  const int width = (int)i420.width;
  const int height = (int)i420.height;

  const int chromaW = (width + 1) / 2;
  const int chromaH = (height + 1) / 2;
  const size_t packedSize = (size_t)(width * height + 2 * chromaW * chromaH);

  // Init/Reinit native buffer on first frame or size change.
  if (!_nativeInited || width != _lastWidth || height != _lastHeight) {
    if (_nativeInited) {
      freeNativeBufferFFI(self.trackId.UTF8String);
      _nativeInited = NO;
    }
    int ok = initNativeBufferFFI(self.trackId.UTF8String, kDefaultCapacity, (int)packedSize);
    if (ok == 0) {
      NSLog(@"[FrameStreamer] initNativeBufferFFI failed for track=%@ size=%dx%d", self.trackId, width, height);
      return;
    }
    _nativeInited = YES;
    _lastWidth = width;
    _lastHeight = height;
    _packingBuffer = [NSMutableData dataWithLength:packedSize];
    NSLog(@"[FrameStreamer] initNativeBufferFFI(track=%@, cap=%d, buf=%zu) OK", self.trackId, kDefaultCapacity, packedSize);
  } else {
    if (!_packingBuffer || _packingBuffer.length < packedSize) {
      _packingBuffer = [NSMutableData dataWithLength:packedSize];
    }
  }

  uint8_t *dst = (uint8_t *)_packingBuffer.mutableBytes;

  // Copy Y plane
  const uint8_t *srcY = (const uint8_t *)i420.dataY;
  const int strideY = (int)i420.strideY;
  for (int r = 0; r < height; ++r) {
    memcpy(dst + r * width, srcY + r * strideY, (size_t)width);
  }
  size_t offset = (size_t)(width * height);

  // Copy U plane
  const uint8_t *srcU = (const uint8_t *)i420.dataU;
  const int strideU = (int)i420.strideU;
  for (int r = 0; r < chromaH; ++r) {
    memcpy(dst + offset + r * chromaW, srcU + r * strideU, (size_t)chromaW);
  }
  offset += (size_t)(chromaW * chromaH);

  // Copy V plane
  const uint8_t *srcV = (const uint8_t *)i420.dataV;
  const int strideV = (int)i420.strideV;
  for (int r = 0; r < chromaH; ++r) {
    memcpy(dst + offset + r * chromaW, srcV + r * strideV, (size_t)chromaW);
  }

  const uint64_t tsMs = (uint64_t)(frame.timeStampNs / 1000000LL);
  const int rotation = (int)frame.rotation;

  // Push packed I420
  int pushed = pushVideoNativeBufferFFI(self.trackId.UTF8String,
                                        (const uint8_t *)_packingBuffer.bytes,
                                        _packingBuffer.length,
                                        width,
                                        height,
                                        tsMs,
                                        rotation,
                                        kColorFormatI420,
                                        0);
  if (pushed == 0) {
    NSLog(@"[FrameStreamer] pushVideoNativeBufferFFI failed for track=%@", self.trackId);
  }
}

@end
