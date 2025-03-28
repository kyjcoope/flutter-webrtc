#import "RTCVideoDecoderBypass.h"
#import <WebRTC/WebRTC.h>
#import <CoreVideo/CoreVideo.h>
#import "NativeBufferBridge.h"

#define WEBRTC_VIDEO_CODEC_OK 0
#define WEBRTC_VIDEO_CODEC_ERROR -1

@implementation RTCVideoDecoderBypass {
    NSString *_trackId;
    RTCVideoCodecInfo *_codecInfo;
    BOOL _isRingBufferInitialized;
    RTCVideoDecoderCallback _callback;
}

- (instancetype)initWithTrackId:(NSString *)trackId codecInfo:(RTCVideoCodecInfo *)codecInfo {
    NSLog(@"RTCVideoDecoderBypass: initWithTrackId: %@, Codec: %@", trackId, codecInfo.name);
    self = [super init];
    if (self) {
        _trackId = trackId ? [trackId copy] : nil;
        _codecInfo = codecInfo;
        _isRingBufferInitialized = NO;
    }
    return self;
}

- (void)dealloc {
    NSLog(@"RTCVideoDecoderBypass: dealloc for trackId: %@", _trackId);
    [self releaseDecoder];
}

- (int)codecStringToInt:(NSString *)codecName {
    if (!codecName) return 0; // VIDEO_CODEC_UNKNOWN

    NSString *lowerCaseName = [codecName lowercaseString];
    if ([lowerCaseName containsString:@"h264"]) return 1;  // VIDEO_CODEC_H264
    if ([lowerCaseName containsString:@"h265"]) return 2;  // VIDEO_CODEC_H265
    if ([lowerCaseName containsString:@"vp8"]) return 3;   // VIDEO_CODEC_VP8
    if ([lowerCaseName containsString:@"vp9"]) return 4;   // VIDEO_CODEC_VP9
    if ([lowerCaseName containsString:@"av1"]) return 5;   // VIDEO_CODEC_AV1
    return 0;
}


- (NSInteger)startDecodeWithNumberOfCores:(int)numberOfCores {
    NSLog(@"RTCVideoDecoderBypass: startDecodeWithNumberOfCores for trackId: %@", _trackId);
    return WEBRTC_VIDEO_CODEC_OK;
}

- (NSInteger)releaseDecoder {
    NSLog(@"RTCVideoDecoderBypass: Releasing decoder for trackId: %@", _trackId);
    if (_trackId != nil && _isRingBufferInitialized) {
        [NativeBufferBridge freeBuffer:_trackId];
        _isRingBufferInitialized = NO;
    }
    _trackId = nil;
    _codecInfo = nil;
    return WEBRTC_VIDEO_CODEC_OK;
}

- (NSInteger)decode:(RTC_OBJC_TYPE(RTCEncodedImage) *)encodedImage
        missingFrames:(BOOL)missingFrames
    codecSpecificInfo:(nullable id<RTC_OBJC_TYPE(RTCCodecSpecificInfo)>)info
         renderTimeMs:(int64_t)renderTimeMs {

    if (!_trackId) {
         NSLog(@"RTCVideoDecoderBypass: Error - Decode called on released decoder or with nil trackId.");
         return WEBRTC_VIDEO_CODEC_ERROR;
    }
    if (!encodedImage) {
        NSLog(@"RTCVideoDecoderBypass: Error - Input encodedImage is null for trackId: %@", _trackId);
        return WEBRTC_VIDEO_CODEC_ERROR;
    }

    NSData *buffer = encodedImage.buffer;
    if (!buffer || buffer.length == 0) {
        NSLog(@"RTCVideoDecoderBypass: Warning - Frame buffer is null or empty for trackId: %@", _trackId);
        return WEBRTC_VIDEO_CODEC_OK;
    }

    if (!_isRingBufferInitialized) {
        int bufferSize = 1024 * 1024 * 2 + 256;
        int capacity = 10;
        NSLog(@"RTCVideoDecoderBypass: Initialize native buffer: %@ with capacity: %d and buffer size: %d", _trackId, capacity, bufferSize);

        BOOL initSuccess = [NativeBufferBridge initializeBuffer:_trackId capacity:capacity maxBufferSize:bufferSize];
        if (!initSuccess) {
            NSLog(@"RTCVideoDecoderBypass: Error - Failed to initialize native buffer for trackId: %@", _trackId);
            return WEBRTC_VIDEO_CODEC_ERROR;
        }
        _isRingBufferInitialized = YES;
        NSLog(@"RTCVideoDecoderBypass: Native buffer initialized for trackId: %@", _trackId);
    }

    int32_t width = encodedImage.encodedWidth;
    int32_t height = encodedImage.encodedHeight;
    int rotation = encodedImage.rotation;
    int frameType = (int)encodedImage.frameType;
    int codecTypeValue = [self codecStringToInt:(_codecInfo ? _codecInfo.name : nil)];
    BOOL pushSuccess = [NativeBufferBridge pushVideoBuffer:_trackId
                                                    buffer:buffer
                                                     width:width
                                                    height:height
                                                 frameTime:renderTimeMs
                                                  rotation:rotation
                                                 frameType:frameType
                                                 codecType:codecTypeValue];

    if (!pushSuccess) {
        NSLog(@"RTCVideoDecoderBypass: Error - Failed to push frame to native buffer for trackId: %@", _trackId);
        return WEBRTC_VIDEO_CODEC_ERROR;
    }

    return WEBRTC_VIDEO_CODEC_OK;
}

- (void)setCallback:(RTCVideoDecoderCallback)callback {
    NSLog(@"RTCVideoDecoderBypass: setCallback for trackId: %@", _trackId);
    _callback = callback;
}

- (NSString *)implementationName {
    return @"RTCVideoDecoderBypass";
}

@end