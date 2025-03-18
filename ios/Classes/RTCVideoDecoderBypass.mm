#import "RTCVideoDecoderBypass.h"
#import <WebRTC/WebRTC.h>
#import <CoreVideo/CoreVideo.h>
#import "NativeBufferBridge.h"

#define WEBRTC_VIDEO_CODEC_OK 0
#define WEBRTC_VIDEO_CODEC_ERROR -1

@implementation RTCVideoDecoderBypass {
    NSString *_trackId;
    BOOL _isRingBufferInitialized;
    RTCVideoDecoderCallback _callback;
}

- (instancetype)initWithTrackId:(NSString *)trackId {
    NSLog(@"SuperDecoder: initWithTrackId");
    self = [super init];
    if (self) {
        _trackId = trackId ? [trackId copy] : nil;
        _isRingBufferInitialized = NO;
    }
    return self;
}

- (void)dealloc {
    NSLog(@"SuperDecoder: dealloc");
    [self releaseDecoder];
}

- (NSInteger)startDecodeWithNumberOfCores:(int)numberOfCores {
    NSLog(@"SuperDecoder: Initializing decoder for trackId: %@", _trackId);
    return WEBRTC_VIDEO_CODEC_OK;
}

- (NSInteger)releaseDecoder {
    NSLog(@"SuperDecoder: Releasing decoder for trackId: %@", _trackId);
    if (_trackId != nil) {
        [NativeBufferBridge freeBufferWithKey:_trackId];
    }
    return WEBRTC_VIDEO_CODEC_OK;
}

- (NSInteger)decode:(RTC_OBJC_TYPE(RTCEncodedImage) *)encodedImage
        missingFrames:(BOOL)missingFrames
    codecSpecificInfo:(nullable id<RTC_OBJC_TYPE(RTCCodecSpecificInfo)>)info
         renderTimeMs:(int64_t)renderTimeMs {

    if (info) {
        NSLog(@"Received codec specific info");
        // Note: RTCCodecSpecificInfo is a protocol, actual implementation may vary
        if ([info respondsToSelector:@selector(codecName)]) {
            NSLog(@"Codec name: %@", [info performSelector:@selector(codecName)]);
        } 
    }
    
    if (!encodedImage) {
        NSLog(@"Input image is null");
        return WEBRTC_VIDEO_CODEC_ERROR;
    }
    
    NSData *buffer = encodedImage.buffer;
    if (!buffer || buffer.length == 0) {
        NSLog(@"Frame buffer is null or empty");
        return WEBRTC_VIDEO_CODEC_ERROR;
    }
    
    if (!_isRingBufferInitialized) {
        int bufferSize = 1024 * 1024 * 2 + 256; // 2MB + 256 bytes
        int capacity = 10;
        NSLog(@"Initialize native buffer: %@ with capacity: %d and buffer size: %d", _trackId, capacity, bufferSize);
        int res = [NativeBufferBridge initBufferWithKey:_trackId capacity:capacity maxBufferSize:bufferSize];
        if (res == 0) {
            NSLog(@"Failed to initialize native buffer");
            return WEBRTC_VIDEO_CODEC_ERROR;
        }
        _isRingBufferInitialized = YES;
        NSLog(@"Native buffer initialized with slot size: %d", bufferSize);
    }
    
    int32_t width = encodedImage.encodedWidth;
    int32_t height = encodedImage.encodedHeight;
    int rotation = encodedImage.rotation;
    int frameType = encodedImage.frameType;
    
    NSLog(@"Frame info - width: %d, height: %d, rotation: %d, frameType: %d, bufferSize: %lu", 
          width, height, rotation, frameType, (unsigned long)buffer.length);
    
    NSLog(@"First 10 bytes: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x",
        ((uint8_t*)buffer.bytes)[0],
        ((uint8_t*)buffer.bytes)[1], 
        ((uint8_t*)buffer.bytes)[2],
        ((uint8_t*)buffer.bytes)[3],
        ((uint8_t*)buffer.bytes)[4],
        ((uint8_t*)buffer.bytes)[5],
        ((uint8_t*)buffer.bytes)[6],
        ((uint8_t*)buffer.bytes)[7],
        ((uint8_t*)buffer.bytes)[8],
        ((uint8_t*)buffer.bytes)[9]);
    
    unsigned long long storedAddress = [NativeBufferBridge pushBuffer:_trackId
                                                              buffer:buffer
                                                               width:width
                                                              height:height
                                                           frameTime:renderTimeMs
                                                            rotation:rotation
                                                           frameType:frameType];
    
    if (storedAddress == 0) {
        NSLog(@"Failed to store frame in native buffer");
        return WEBRTC_VIDEO_CODEC_ERROR;
    }
    
    return WEBRTC_VIDEO_CODEC_OK;
}

- (void)setCallback:(RTCVideoDecoderCallback)callback {
    NSLog(@"SuperDecoder: setCallback");
    _callback = callback;
}

- (NSString *)implementationName {
    return @"RTCVideoDecoderBypass";
}

@end