#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomVideoDecoderFactory : NSObject <RTCVideoDecoderFactory>

+ (void)setTrackId:(NSString *)trackId;

@end

NS_ASSUME_NONNULL_END