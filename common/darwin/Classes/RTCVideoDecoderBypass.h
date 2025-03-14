#import <Foundation/Foundation.h>
#import <WebRTC/RTCMacros.h>
#import <WebRTC/RTCVideoDecoder.h>

NS_ASSUME_NONNULL_BEGIN

@interface RTCVideoDecoderBypass : NSObject <RTC_OBJC_TYPE(RTCVideoDecoder)>

- (instancetype)initWithTrackId:(NSString * _Nullable)trackId;

@end

NS_ASSUME_NONNULL_END