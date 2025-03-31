#import "CustomVideoDecoderFactory.h"
#import "RTCVideoDecoderBypass.h"
#import <WebRTC/WebRTC.h>

@implementation CustomVideoDecoderFactory {
}

static NSMutableArray<NSString *> *trackQueue;

+ (void)initialize {
    NSLog(@"CustomVideoDecoderFactory: initialize");
    if (self == [CustomVideoDecoderFactory class]) {
        trackQueue = [NSMutableArray array];
    }
}

+ (void)setTrackId:(NSString *)trackId {
    @synchronized(trackQueue) {
        NSLog(@"CustomVideoDecoderFactory: Adding trackId to queue: %@", trackId);
        [trackQueue addObject:trackId];
    }
}

- (instancetype)init {
    NSLog(@"CustomVideoDecoderFactory: init");
    self = [super init];
    return self;
}

- (id<RTCVideoDecoder>)createDecoder:(RTCVideoCodecInfo *)info {
    NSLog(@"CustomVideoDecoderFactory: Creating decoder for codec: %@", info.name);
    NSString *trackId = nil;
    
    @synchronized(trackQueue) {
        if (trackQueue.count > 0) {
            trackId = trackQueue[0];
            [trackQueue removeObjectAtIndex:0];
            NSLog(@"CustomVideoDecoderFactory: Creating decoder with trackId: %@", trackId);
        } else {
            NSLog(@"CustomVideoDecoderFactory: Warning: Creating decoder with no associated trackId");
        }
    }
    return [[RTCVideoDecoderBypass alloc] initWithTrackId:trackId codecInfo:info];
}

- (NSArray<RTCVideoCodecInfo *> *)supportedCodecs {
    RTCVideoCodecInfo *h264 = [[RTCVideoCodecInfo alloc] initWithName:@"H264"];
    RTCVideoCodecInfo *vp8 = [[RTCVideoCodecInfo alloc] initWithName:@"VP8"];
    RTCVideoCodecInfo *vp9 = [[RTCVideoCodecInfo alloc] initWithName:@"VP9"];

    return @[h264, vp8, vp9];
}

@end