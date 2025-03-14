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

- (id<RTCVideoDecoder>)createDecoder:(RTCVideoCodecInfo *)info {
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

- (NSArray<RTCVideoCodecInfo *> *)supportedCodecs {
    NSString *vp8Name = @"VP8";
    NSString *vp9Name = @"VP9";
    NSString *h264Name = @"H264";
    
    return @[
        [[RTCVideoCodecInfo alloc] initWithName:vp8Name],
        [[RTCVideoCodecInfo alloc] initWithName:vp9Name],
        [[RTCVideoCodecInfo alloc] initWithName:h264Name]
    ];
}

@end