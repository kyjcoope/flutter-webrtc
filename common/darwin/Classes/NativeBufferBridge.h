#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativeBufferBridge : NSObject

+ (int)initBufferWithKey:(NSString *)key capacity:(int)capacity maxBufferSize:(int)maxBufferSize;
+ (unsigned long long)pushBuffer:(NSString *)key 
                          buffer:(NSData *)buffer
                           width:(int)width 
                          height:(int)height
                       frameTime:(int64_t)frameTime
                        rotation:(int)rotation
                       frameType:(int)frameType;
+ (void)freeBufferWithKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END