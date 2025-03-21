#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <WebRTC/WebRTC.h>
#import "FlutterWebRTCPlugin.h"

@interface RTCMediaStreamTrack (Flutter)
@property(nonatomic, strong, nonnull) id settings;
@end

@interface RTCAudioInterceptor : NSObject <RTCAudioRenderer>
- (instancetype)init;
- (void)renderPCMBuffer:(AVAudioPCMBuffer *)pcmBuffer;
@end

@interface FlutterWebRTCPlugin (RTCMediaStream)

@property(nonatomic, strong, nullable) RTCAudioInterceptor *audioInterceptor;

- (void)getUserMedia:(nonnull NSDictionary*)constraints result:(nonnull FlutterResult)result;

- (void)createLocalMediaStream:(nonnull FlutterResult)result;

- (void)getSources:(nonnull FlutterResult)result;

- (void)mediaStreamTrackCaptureFrame:(nonnull RTCMediaStreamTrack*)track
                              toPath:(nonnull NSString*)path
                              result:(nonnull FlutterResult)result;

- (void)selectAudioInput:(nonnull NSString*)deviceId result:(nullable FlutterResult)result;

- (void)selectAudioOutput:(nonnull NSString*)deviceId result:(nullable FlutterResult)result;

- (void)startAudioInterception;
- (void)stopAudioInterception;

@end
