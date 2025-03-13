#import "VideoDecoderBypass.h"
#import <WebRTC/RTCVideoCodecInfo.h>
#import <WebRTC/RTCVideoFrame.h>
#import <WebRTC/RTCCodecSpecificInfo.h>

#ifdef __cplusplus
extern "C" {
#endif
int initNativeBufferFFI(const char* key, int capacity, int maxBufferSize);
unsigned long long pushNativeBufferFFI(const char* key, uint8_t* buffer, int dataSize,
                                      int width, int height, uint64_t frameTime, int rotation, int frameType);
void freeNativeBufferFFI(const char* key);
#ifdef __cplusplus
}
#endif

@implementation RTCVideoDecoderBypass {
    NSString *_trackId;
    BOOL _isRingBufferInitialized;
    RTCVideoDecoderCallback _callback;
}

- (instancetype)initWithTrackId:(NSString *)trackId {
    self = [super init];
    if (self) {
        _trackId = trackId;
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
    
    CVPixelBufferRef pixelBuffer = inputImage.buffer;
    if (!pixelBuffer) {
        NSLog(@"Frame buffer is null");
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
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    uint8_t *bufferData = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t dataSize = CVPixelBufferGetDataSize(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    unsigned long long storedAddress = pushNativeBufferFFI([_trackId UTF8String], 
                                                          bufferData, 
                                                          (int)dataSize, 
                                                          (int)width, 
                                                          (int)height, 
                                                          renderTimeMs, 
                                                          inputImage.rotation, 
                                                          inputImage.frameType);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
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