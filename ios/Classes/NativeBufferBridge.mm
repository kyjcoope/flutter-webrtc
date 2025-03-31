#import "NativeBufferBridge.h"
#import "native_buffer_api.h"

@implementation NativeBufferBridge

+ (BOOL)initializeBuffer:(NSString *)key capacity:(int)capacity maxBufferSize:(int)maxBufferSize {
    if (!key) return NO;
    int result = initNativeBufferFFI([key UTF8String], capacity, maxBufferSize);
    return (result != 0);
}

+ (BOOL)pushVideoBuffer:(NSString *)key
                 buffer:(NSData *)buffer
                  width:(int)width
                 height:(int)height
              frameTime:(int64_t)frameTime
               rotation:(int)rotation
              frameType:(int)frameType
              codecType:(int)codecType {
    if (!key || !buffer) {
        NSLog(@"NativeBufferBridge: Error - Pushing video with nil key or buffer.");
        return NO;
    }

    const uint8_t *bytes = (const uint8_t *)[buffer bytes];
    size_t length = (size_t)[buffer length];

    if (length == 0) {
         NSLog(@"NativeBufferBridge: Warning - Pushing empty video buffer for key: %@", key);
         return YES;
    }

    int ffi_result = pushVideoNativeBufferFFI(
        [key UTF8String],
        bytes,
        length,
        width,
        height,
        (uint64_t)frameTime,
        rotation,
        frameType,
        codecType
    );

    return (ffi_result != 0);
}

+ (BOOL)pushAudioBuffer:(NSString *)key
                 buffer:(NSData *)buffer
             sampleRate:(int)sampleRate
               channels:(int)channels {
    if (!key || !buffer) {
        NSLog(@"NativeBufferBridge: Error - Pushing audio with nil key or buffer.");
        return NO;
    }

    const uint8_t *bytes = (const uint8_t *)[buffer bytes];
    size_t length = (size_t)[buffer length];

    if (length == 0) {
        NSLog(@"NativeBufferBridge: Warning - Pushing empty audio buffer for key: %@", key);
        return YES;
    }

    uint64_t frameTime = (uint64_t)([[NSDate date] timeIntervalSince1970] * 1000.0);

    int ffi_result = pushAudioNativeBufferFFI(
        [key UTF8String],
        bytes,
        length,
        sampleRate,
        channels,
        frameTime
    );

    return (ffi_result != 0);
}

+ (unsigned long long)popBuffer:(NSString *)key {
    if (!key) return 0;
    return (unsigned long long)popNativeBufferFFI([key UTF8String]);
}

+ (void)freeBuffer:(NSString *)key {
    if (!key) return;
    freeNativeBufferFFI([key UTF8String]);
}

@end