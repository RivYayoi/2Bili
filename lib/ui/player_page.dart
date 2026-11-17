import 'package:flutter/material.dart';

import 'video_player_panel.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({
    super.key,
    required this.bvid,
    required this.cid,
    required this.title,
    this.startPositionMs = 0,
  });

  final String bvid;
  final int cid;
  final String title;
  final int startPositionMs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: VideoPlayerPanel(
        bvid: bvid,
        cid: cid,
        title: title,
        fullscreen: true,
        startPositionMs: startPositionMs,
        onExitFullscreen: (positionMs) => Navigator.of(context).pop(positionMs),
      ),
    );
  }
}
