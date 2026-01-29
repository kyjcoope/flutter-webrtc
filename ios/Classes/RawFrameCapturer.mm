#import "RawFrameCapturer.h"
#import <WebRTC/RTCI420Buffer.h>
#import <WebRTC/RTCVideoFrame.h>


#include "native_buffer_api.h"

static const int kDefaultCapacity = 16;

@implementation RawFrameCapturer {
  __weak RTC_OBJC_TYPE(RTCVideoTrack) * _videoTrack;
  NSString* _trackId;
  BOOL _capturing;
  BOOL _nativeBufferInitialized;
  int _lastWidth;
  int _lastHeight;
  int _lastBufferSize;
}

- (instancetype)initWithTrack:(RTC_OBJC_TYPE(RTCVideoTrack) *)videoTrack {
  self = [super init];
  if (self) {
    _videoTrack = videoTrack;
    _trackId = videoTrack.trackId;
    _capturing = NO;
    _nativeBufferInitialized = NO;
    _lastWidth = 0;
    _lastHeight = 0;
    _lastBufferSize = 0;
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

  RTC_OBJC_TYPE(RTCVideoTrack)* track = _videoTrack;
  if (!track) {
    NSLog(@"RawFrameCapturer: Cannot start - track is nil");
    return;
  }

  [track addRenderer:self];
  _capturing = YES;
  NSLog(@"RawFrameCapturer: Started capture for track %@", _trackId);
}

- (void)stopCapture {
  if (!_capturing)
    return;

  RTC_OBJC_TYPE(RTCVideoTrack)* track = _videoTrack;
  if (track) {
    [track removeRenderer:self];
  }
  _capturing = NO;

  if (_nativeBufferInitialized) {
    freeNativeBufferFFI([_trackId UTF8String]);
    _nativeBufferInitialized = NO;
  }

  NSLog(@"RawFrameCapturer: Stopped capture for track %@", _trackId);
}

#pragma mark - RTCVideoRenderer

- (void)setSize:(CGSize)size {
  // Size changes are handled in renderFrame
}

- (void)renderFrame:(nullable RTC_OBJC_TYPE(RTCVideoFrame) *)frame {
  if (!frame || !_capturing)
    return;

  // Convert to I420
  id<RTC_OBJC_TYPE(RTCI420Buffer)> i420Buffer = [frame.buffer toI420];
  if (!i420Buffer) {
    NSLog(@"RawFrameCapturer: Failed to convert frame to I420");
    return;
  }

  int width = i420Buffer.width;
  int height = i420Buffer.height;
  int chromaWidth = (width + 1) / 2;
  int chromaHeight = (height + 1) / 2;
  int packedSize = width * height + chromaWidth * chromaHeight * 2;

  // Initialize or reinitialize native buffer if dimensions changed
  if (!_nativeBufferInitialized || width != _lastWidth || height != _lastHeight ||
      packedSize != _lastBufferSize) {
    if (_nativeBufferInitialized) {
      freeNativeBufferFFI([_trackId UTF8String]);
    }

    int result = initNativeBufferFFI([_trackId UTF8String], kDefaultCapacity, packedSize);
    if (result == 0) {
      NSLog(@"RawFrameCapturer: Failed to init native buffer");
      return;
    }

    _nativeBufferInitialized = YES;
    _lastWidth = width;
    _lastHeight = height;
    _lastBufferSize = packedSize;
    NSLog(@"RawFrameCapturer: Initialized buffer for %dx%d (size=%d)", width, height, packedSize);
  }

  // Pack I420 planes tightly
  NSMutableData* packedData = [NSMutableData dataWithCapacity:packedSize];

  // Y plane
  [self copyPlane:i420Buffer.dataY
           stride:i420Buffer.strideY
       planeWidth:width
      planeHeight:height
         toBuffer:packedData];

  // U plane
  [self copyPlane:i420Buffer.dataU
           stride:i420Buffer.strideU
       planeWidth:chromaWidth
      planeHeight:chromaHeight
         toBuffer:packedData];

  // V plane
  [self copyPlane:i420Buffer.dataV
           stride:i420Buffer.strideV
       planeWidth:chromaWidth
      planeHeight:chromaHeight
         toBuffer:packedData];

  // Push to native buffer
  uint64_t frameTimeMs = frame.timeStampNs / 1000000;
  int rotation = (int)frame.rotation;

  pushVideoNativeBufferFFI([_trackId UTF8String], (const uint8_t*)packedData.bytes,
                           packedData.length, width, height, frameTimeMs, rotation);
}

- (void)copyPlane:(const uint8_t*)src
           stride:(int)stride
       planeWidth:(int)planeWidth
      planeHeight:(int)planeHeight
         toBuffer:(NSMutableData*)buffer {
  for (int row = 0; row < planeHeight; row++) {
    [buffer appendBytes:(src + row * stride) length:planeWidth];
  }
}

@end
