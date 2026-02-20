#ifndef RAW_AUDIO_CAPTURER_H
#define RAW_AUDIO_CAPTURER_H

#import <Foundation/Foundation.h>
#import <WebRTC/RTCAudioTrack.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Captures raw PCM audio from an individual RTCAudioTrack and pushes it
 * to the native ring buffer for FFI consumption.
 * Mirrors the RawFrameCapturer (video) pattern for per-track audio.
 */
@interface RawAudioCapturer : NSObject

@property(nonatomic, readonly) NSString* trackId;
@property(nonatomic, readonly, getter=isCapturing) BOOL capturing;

- (instancetype)initWithTrack:(RTC_OBJC_TYPE(RTCAudioTrack) *)audioTrack;
- (void)startCapture;
- (void)stopCapture;

@end

NS_ASSUME_NONNULL_END

#endif  // RAW_AUDIO_CAPTURER_H
