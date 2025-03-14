#import "CustomVideoDecoderFactory.h"
#import "RTCVideoDecoderBypass.h"
#import <WebRTC/RTCMacros.h>
#import <WebRTC/RTCVideoCodecInfo.h>

@implementation CustomVideoDecoderFactory {
}

static NSMutableArray<NSString *> *trackQueue;

+ (void)initialize {
    if (self == [CustomVideoDecoderFactory class]) {
        trackQueue = [NSMutableArray array];
    }
}

+ (void)setTrackId:(NSString *)trackId {
    @synchronized(trackQueue) {
        NSLog(@"Adding trackId to queue: %@", trackId);
        [trackQueue addObject:trackId];
    }
}

- (instancetype)init {
    self = [super init];
    return self;
}

- (id<RTC_OBJC_TYPE(RTCVideoDecoder)>)createDecoder:(RTC_OBJC_TYPE(RTCVideoCodecInfo) *)info {
    NSString *trackId = nil;
    
    @synchronized(trackQueue) {
        if (trackQueue.count > 0) {
            trackId = trackQueue[0];
            [trackQueue removeObjectAtIndex:0];
            NSLog(@"Creating decoder with trackId: %@", trackId);
        } else {
            NSLog(@"Warning: Creating decoder with no associated trackId");
        }
    }
    
    return [[RTCVideoDecoderBypass alloc] initWithTrackId:trackId];
}

- (NSArray<RTC_OBJC_TYPE(RTCVideoCodecInfo) *> *)supportedCodecs {
    RTC_OBJC_TYPE(RTCVideoCodecInfo) *vp8 = [[RTC_OBJC_TYPE(RTCVideoCodecInfo) alloc] initWithName:@"VP8"];
    RTC_OBJC_TYPE(RTCVideoCodecInfo) *vp9 = [[RTC_OBJC_TYPE(RTCVideoCodecInfo) alloc] initWithName:@"VP9"];
    RTC_OBJC_TYPE(RTCVideoCodecInfo) *h264 = [[RTC_OBJC_TYPE(RTCVideoCodecInfo) alloc] initWithName:@"H264"];
    
    return @[vp8, vp9, h264];
}

@end