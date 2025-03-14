#import "RTCVideoDecoderBypass.h"
#import <WebRTC/WebRTC.h>
#import <CoreVideo/CoreVideo.h>

#include "buffer/native_buffer_api.h"

@implementation RTCVideoDecoderBypass {
    NSString *_trackId;
    BOOL _isRingBufferInitialized;
    RTCVideoDecoderCallback _callback;
}

- (instancetype)initWithTrackId:(NSString *)trackId {
    self = [super init];
    if (self) {
        _trackId = trackId ? [trackId copy] : nil;
        _isRingBufferInitialized = NO;
    }
    return self;
}

- (void)dealloc {
    [self releaseDecoder];
}

- (BOOL)startDecodeWithNumberOfCores:(int)numberOfCores {
    NSLog(@"Initializing decoder for trackId: %@", _trackId);
    return YES;
}

- (void)releaseDecoder {
    NSLog(@"Releasing decoder for trackId: %@", _trackId);
    if (_trackId != nil) {
        freeNativeBufferFFI([_trackId UTF8String]);
    }
}

- (NSInteger)decode:(RTCEncodedImage *)inputImage
        missingFrames:(BOOL)missingFrames
    codecSpecificInfo:(nullable id<RTCCodecSpecificInfo>)info
         renderTimeMs:(int64_t)renderTimeMs {
    
    if (!inputImage) {
        NSLog(@"Input image is null");
        return WEBRTC_VIDEO_CODEC_ERROR;
    }
    
    NSData *buffer = [inputImage buffer];
    
    if (!buffer || buffer.length == 0) {
        NSLog(@"Frame buffer is null or empty");
        return WEBRTC_VIDEO_CODEC_ERROR;
    }
    
    if (!_isRingBufferInitialized) {
        int bufferSize = 1024 * 1024 * 2 + 256; // 2MB + 256 bytes
        int capacity = 10;
        NSLog(@"Initialize native buffer: %@ with capacity: %d and buffer size: %d", _trackId, capacity, bufferSize);
        int res = initNativeBufferFFI([_trackId UTF8String], capacity, bufferSize);
        if (res == 0) {
            NSLog(@"Failed to initialize native buffer");
            return WEBRTC_VIDEO_CODEC_ERROR;
        }
        _isRingBufferInitialized = YES;
        NSLog(@"Native buffer initialized with slot size: %d", bufferSize);
    }
    
    const uint8_t *bufferData = (const uint8_t *)buffer.bytes;
    int dataSize = (int)buffer.length;
    
    int32_t width = (int32_t)[inputImage encodedWidth];
    int32_t height = (int32_t)[inputImage encodedHeight];
    int rotation = (int)[inputImage rotation];
    int frameType = (int)[inputImage frameType];
    
    NSLog(@"Processing frame: size=%d, %dx%d, type=%d", dataSize, width, height, frameType);
    
    unsigned long long storedAddress = pushNativeBufferFFI([_trackId UTF8String], 
                                                          bufferData,
                                                          dataSize, 
                                                          width, 
                                                          height, 
                                                          renderTimeMs, 
                                                          rotation, 
                                                          frameType);
    
    if (storedAddress == 0) {
        NSLog(@"Failed to store frame in native buffer");
        return WEBRTC_VIDEO_CODEC_ERROR;
    }
    
    return WEBRTC_VIDEO_CODEC_OK;
}

- (void)setCallback:(RTCVideoDecoderCallback)callback {
    _callback = callback;
}

- (NSString *)implementationName {
    return @"RTCVideoDecoderBypass";
}

@end