#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomVideoDecoderFactory : NSObject <RTC_OBJC_TYPE(RTCVideoDecoderFactory)>

+ (void)setTrackId:(NSString *)trackId;

@end

NS_ASSUME_NONNULL_END