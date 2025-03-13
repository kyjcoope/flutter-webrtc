#import <Foundation/Foundation.h>
#import <WebRTC/RTCVideoDecoder.h>

@interface RTCVideoDecoderBypass : NSObject <RTCVideoDecoder>

- (instancetype)initWithTrackId:(NSString *)trackId;

@end