#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

NS_ASSUME_NONNULL_BEGIN

@interface RTCVideoDecoderBypass : NSObject <RTCVideoDecoder>

- (instancetype)initWithTrackId:(NSString * _Nullable)trackId codecInfo:(RTCVideoCodecInfo *)codecInfo;

@end

NS_ASSUME_NONNULL_END