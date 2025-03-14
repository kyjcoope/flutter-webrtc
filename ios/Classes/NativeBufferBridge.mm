#import "NativeBufferBridge.h"
#include "native_buffer_api.h"

@implementation NativeBufferBridge

+ (int)initBufferWithKey:(NSString *)key capacity:(int)capacity maxBufferSize:(int)maxBufferSize {
    return initNativeBufferFFI([key UTF8String], capacity, maxBufferSize);
}

+ (unsigned long long)pushBuffer:(NSString *)key 
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

+ (void)freeBufferWithKey:(NSString *)key {
    freeNativeBufferFFI([key UTF8String]);
}

@end