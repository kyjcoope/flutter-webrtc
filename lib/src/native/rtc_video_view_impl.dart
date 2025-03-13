import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/bindings/encoded_webrtc_frame.dart';
import 'package:flutter_webrtc/bindings/native_bindings.dart';

import 'package:webrtc_interface/webrtc_interface.dart';

import 'rtc_video_renderer_impl.dart';

import 'dart:developer' as dev;

class RTCVideoView extends StatefulWidget {
  RTCVideoView(
    this._renderer, {
    super.key,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    this.mirror = false,
    this.filterQuality = FilterQuality.low,
    this.placeholderBuilder,
    this.trackId,
  });
  final String? trackId;
  final RTCVideoRenderer _renderer;
  final RTCVideoViewObjectFit objectFit;
  final bool mirror;
  final FilterQuality filterQuality;
  final WidgetBuilder? placeholderBuilder;

  @override
  State<StatefulWidget> createState() => _RTCVideoView();
}

class _RTCVideoView extends State<RTCVideoView> {
  Timer? _frameTimer;

  @override
  void initState() {
    super.initState();
    if (widget.trackId != null) {
      _startFrameTimer();
    }
  }

  @override
  void didUpdateWidget(covariant RTCVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId == null &&
        widget.trackId != null &&
        _frameTimer == null) {
      _startFrameTimer();
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    super.dispose();
  }

  void _startFrameTimer() {
    dev.log('Dart -> TRACK ID: ${widget.trackId}');
    _frameTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      try {
        if (widget.trackId == null) return;
        EncodedWebRTCFrame? frame = popFrameFromTrack(widget.trackId!);
        if (frame == null) return;
        dev.log(
            'FRAME: ${frame.width}x${frame.height}, time: ${frame.frameTime}');
      } catch (e) {
        print("Error pulling frame: $e");
      }
    });
  }

  RTCVideoRenderer get videoRenderer => widget._renderer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            _buildVideoView(context, constraints));
  }

  Widget _buildVideoView(BuildContext context, BoxConstraints constraints) {
    return Center(
      child: Container(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: FittedBox(
          clipBehavior: Clip.hardEdge,
          fit: widget.objectFit ==
                  RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
              ? BoxFit.contain
              : BoxFit.cover,
          child: Center(
            child: ValueListenableBuilder<RTCVideoValue>(
              valueListenable: videoRenderer,
              builder:
                  (BuildContext context, RTCVideoValue value, Widget? child) {
                return SizedBox(
                  width: constraints.maxHeight * value.aspectRatio,
                  height: constraints.maxHeight,
                  child: child,
                );
              },
              child: Transform(
                transform: Matrix4.identity()
                  ..rotateY(widget.mirror ? -pi : 0.0),
                alignment: FractionalOffset.center,
                child: videoRenderer.renderVideo
                    ? Texture(
                        textureId: videoRenderer.textureId!,
                        filterQuality: widget.filterQuality,
                      )
                    : widget.placeholderBuilder?.call(context) ?? Container(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
