#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

NS_ASSUME_NONNULL_BEGIN

@interface FrameStreamer : NSObject<RTCVideoRenderer>

- (instancetype)initWithTrack:(RTCVideoTrack *)track;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
