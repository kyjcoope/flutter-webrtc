#import "NativeBufferBridge.h"
#include "native_buffer_api.h"

@implementation NativeBufferBridge

+ (BOOL)initializeBuffer:(NSString *)key capacity:(int)capacity maxBufferSize:(int)maxBufferSize {
    return initNativeBufferFFI([key UTF8String], capacity, maxBufferSize) != 0;
}

+ (unsigned long long)pushVideoBuffer:(NSString *)key 
                              buffer:(NSData *)buffer
                               width:(int)width 
                              height:(int)height
                           frameTime:(int64_t)frameTime
                            rotation:(int)rotation
                           frameType:(int)frameType {
    return pushNativeBufferFFI([key UTF8String], 
                              (const uint8_t *)[buffer bytes], 
                              (int)[buffer length], 
                              width, 
                              height, 
                              frameTime, 
                              rotation, 
                              frameType);
}

+ (BOOL)pushAudioBuffer:(NSString *)key
                 buffer:(NSData *)buffer
             sampleRate:(int)sampleRate
               channels:(int)channels {
    unsigned long long result = pushAudioNativeBufferFFI([key UTF8String],
                                                     (const uint8_t *)[buffer bytes],
                                                     (int)[buffer length],
                                                     sampleRate,
                                                     channels,
                                                     (uint64_t)([[NSDate date] timeIntervalSince1970] * 1000));
    return result != 0;
}

+ (unsigned long long)popBuffer:(NSString *)key {
    return popNativeBufferFFI([key UTF8String]);
}

+ (void)freeBuffer:(NSString *)key {
    freeNativeBufferFFI([key UTF8String]);
}

@end