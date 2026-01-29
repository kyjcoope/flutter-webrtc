#ifndef RAW_FRAME_CAPTURER_H
#define RAW_FRAME_CAPTURER_H

#import <Foundation/Foundation.h>
#import <WebRTC/RTCVideoRenderer.h>
#import <WebRTC/RTCVideoTrack.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Captures raw video frames from an RTCVideoTrack and pushes them
 * to the native ring buffer for FFI consumption.
 */
@interface RawFrameCapturer : NSObject <RTC_OBJC_TYPE (RTCVideoRenderer)>

@property(nonatomic, readonly) NSString* trackId;
@property(nonatomic, readonly, getter=isCapturing) BOOL capturing;

- (instancetype)initWithTrack:(RTC_OBJC_TYPE(RTCVideoTrack) *)videoTrack;
- (void)startCapture;
- (void)stopCapture;

@end

NS_ASSUME_NONNULL_END

#endif  // RAW_FRAME_CAPTURER_H
