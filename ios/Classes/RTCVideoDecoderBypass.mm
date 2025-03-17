#import "RTCVideoDecoderBypass.h"
#import <WebRTC/WebRTC.h>
#import <CoreVideo/CoreVideo.h>
#import "NativeBufferBridge.h"

#define WEBRTC_VIDEO_CODEC_OK 0
#define WEBRTC_VIDEO_CODEC_ERROR -1

@implementation RTCVideoDecoderBypass {
    NSString *_trackId;
    BOOL _isRingBufferInitialized;
    id _callback;
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

- (BOOL)startDecodeWithNumberOfCores:(int)numberOfCores {
    NSLog(@"SuperDecoder: Initializing decoder for trackId: %@", _trackId);
    return YES;
}

- (NSInteger)releaseDecoder {
    NSLog(@"SuperDecoder: Releasing decoder for trackId: %@", _trackId);
    if (_trackId != nil) {
        [NativeBufferBridge freeBufferWithKey:_trackId];
    }
    return WEBRTC_VIDEO_CODEC_OK;
}

- (NSInteger)decode:(id)inputImage 
        missingFrames:(BOOL)missingFrames
    codecSpecificInfo:(nullable id)info
         renderTimeMs:(int64_t)renderTimeMs {

    NSLog(@"SuperDecoder: Decode frame called");
    return WEBRTC_VIDEO_CODEC_OK;
    
    // if (!inputImage) {
    //     NSLog(@"Input image is null");
    //     return WEBRTC_VIDEO_CODEC_ERROR;
    // }
    
    // NSData *buffer = [inputImage performSelector:@selector(buffer)];
    
    // if (!buffer || buffer.length == 0) {
    //     NSLog(@"Frame buffer is null or empty");
    //     return WEBRTC_VIDEO_CODEC_ERROR;
    // }
    
    // if (!_isRingBufferInitialized) {
    //     int bufferSize = 1024 * 1024 * 2 + 256; // 2MB + 256 bytes
    //     int capacity = 10;
    //     NSLog(@"Initialize native buffer: %@ with capacity: %d and buffer size: %d", _trackId, capacity, bufferSize);
    //     int res = [NativeBufferBridge initBufferWithKey:_trackId capacity:capacity maxBufferSize:bufferSize];
    //     if (res == 0) {
    //         NSLog(@"Failed to initialize native buffer");
    //         return WEBRTC_VIDEO_CODEC_ERROR;
    //     }
    //     _isRingBufferInitialized = YES;
    //     NSLog(@"Native buffer initialized with slot size: %d", bufferSize);
    // }
    
    // int32_t width = (int32_t)[[inputImage performSelector:@selector(encodedWidth)] intValue];
    // int32_t height = (int32_t)[[inputImage performSelector:@selector(encodedHeight)] intValue];
    // int rotation = (int)[[inputImage performSelector:@selector(rotation)] intValue];
    // int frameType = (int)[[inputImage performSelector:@selector(frameType)] intValue];
    
    // NSLog(@"Processing frame: size=%d, %dx%d, type=%d", (int)buffer.length, width, height, frameType);
    
    // unsigned long long storedAddress = [NativeBufferBridge pushBuffer:_trackId
    //                                                           buffer:buffer
    //                                                            width:width
    //                                                           height:height
    //                                                        frameTime:renderTimeMs
    //                                                         rotation:rotation
    //                                                        frameType:frameType];
    
    // if (storedAddress == 0) {
    //     NSLog(@"Failed to store frame in native buffer");
    //     return WEBRTC_VIDEO_CODEC_ERROR;
    // }
    
    // return WEBRTC_VIDEO_CODEC_OK;
}

- (void)setCallback:(id)callback {
    NSLog(@"SuperDecoder: setCallback");
    _callback = callback;
}

- (NSString *)implementationName {
    return @"RTCVideoDecoderBypass";
}

@end