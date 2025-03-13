#import <Foundation/Foundation.h>
#import <WebRTC/RTCVideoDecoderFactory.h>

@interface CustomVideoDecoderFactory : NSObject <RTCVideoDecoderFactory>

+ (void)setTrackId:(NSString *)trackId;

@end