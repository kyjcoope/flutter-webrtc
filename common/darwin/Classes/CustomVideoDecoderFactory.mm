#import "CustomVideoDecoderFactory.h"
#import "RTCVideoDecoderBypass.h"
#import <WebRTC/RTCVideoCodecInfo.h>

@implementation CustomVideoDecoderFactory {
    dispatch_queue_t _trackQueueDispatchQueue;
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
    if (self) {
        _trackQueueDispatchQueue = dispatch_queue_create("com.cloudwebrtc.trackqueue", DISPATCH_QUEUE_SERIAL);
    }
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
    return @[
        [[RTCVideoCodecInfo alloc] initWithName:@"VP8"],
        [[RTCVideoCodecInfo alloc] initWithName:@"VP9"],
        [[RTCVideoCodecInfo alloc] initWithName:@"H264"]
    ];
}

@end