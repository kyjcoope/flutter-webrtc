import 'dart:math';

import 'package:flutter/material.dart';

import 'package:webrtc_interface/webrtc_interface.dart';

import 'rtc_video_renderer_impl.dart';

class RTCVideoView extends StatefulWidget {
  RTCVideoView(
    this._renderer, {
    super.key,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    this.mirror = false,
    this.filterQuality = FilterQuality.low,
    this.placeholderBuilder,
  });
  final RTCVideoRenderer _renderer;
  final RTCVideoViewObjectFit objectFit;
  final bool mirror;
  final FilterQuality filterQuality;
  final WidgetBuilder? placeholderBuilder;

  @override
  State<StatefulWidget> createState() => _RTCVideoView();
}

class _RTCVideoView extends State<RTCVideoView> {
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
