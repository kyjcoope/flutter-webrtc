#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativeBufferBridge : NSObject

+ (BOOL)initializeBuffer:(NSString *)key capacity:(int)capacity maxBufferSize:(int)maxBufferSize;

+ (BOOL)pushVideoBuffer:(NSString *)key
                 buffer:(NSData *)buffer
                  width:(int)width
                 height:(int)height
              frameTime:(int64_t)frameTime
               rotation:(int)rotation
              frameType:(int)frameType
              codecType:(int)codecType;

+ (BOOL)pushAudioBuffer:(NSString *)key
                 buffer:(NSData *)buffer
             sampleRate:(int)sampleRate
               channels:(int)channels;

+ (unsigned long long)popBuffer:(NSString *)key;

+ (void)freeBuffer:(NSString *)key;

@end

NS_ASSUME_NONNULL_END