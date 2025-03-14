#import <Foundation/Foundation.h>
#import <WebRTC/RTCMacros.h>
#import <WebRTC/RTCVideoDecoderFactory.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomVideoDecoderFactory : NSObject <RTCVideoDecoderFactory>

+ (void)setTrackId:(NSString *)trackId;

@end

NS_ASSUME_NONNULL_END