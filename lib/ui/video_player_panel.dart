import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import '../core/bili_api.dart';
import '../core/danmaku_service.dart';
import '../core/models.dart';
import '../core/settings_store.dart';
import 'danmaku_overlay.dart';
import 'danmaku_settings.dart';

class VideoPlayerPanel extends StatefulWidget {
  const VideoPlayerPanel({
    super.key,
    required this.bvid,
    required this.cid,
    required this.title,
    this.fullscreen = false,
    this.onFullscreen,
    this.onExitFullscreen,
  });

  final String bvid;
  final int cid;
  final String title;
  final bool fullscreen;
  final VoidCallback? onFullscreen;
  final VoidCallback? onExitFullscreen;

  @override
  State<VideoPlayerPanel> createState() => VideoPlayerPanelState();
}

class VideoPlayerPanelState extends State<VideoPlayerPanel>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoController;
  final DanmakuService _danmakuService = DanmakuService();
  final DanmakuBuffer _danmakuBuffer = DanmakuBuffer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  PlayData? _playData;
  PlaySource? _source;
  int _selectedQn = 0;
  bool _loading = true;
  Object? _error;
  bool _playing = false;
  bool _buffering = false;
  int _positionMs = 0;
  int _durationMs = 0;
  double _speed = 1.0;
  bool _dragging = false;
  double _dragValue = 0;
  bool _retrying = false;
  int _sourceIndex = 0;
  List<String> _videoUrls = [];
  List<String> _audioUrls = [];
  StreamSubscription<Danmaku>? _danmakuSubscription;
  int _loadGeneration = 0;
  int _danmakuGeneration = 0;
  Timer? _hideTimer;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.fullscreen) {
      _scheduleFullscreenMode(true);
      _scheduleHide();
    }
    _player = Player(
      configuration: const PlayerConfiguration(
        title: '2bili',
        logLevel: MPVLogLevel.warn,
      ),
    );
    _videoController = VideoController(_player);
    _subscriptions.add(
      _player.stream.playing.listen((value) {
        if (mounted) setState(() => _playing = value);
      }),
    );
    _subscriptions.add(
      _player.stream.buffering.listen((value) {
        if (mounted) setState(() => _buffering = value);
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((value) {
        if (mounted && !_dragging) {
          setState(() => _positionMs = value.inMilliseconds);
        }
      }),
    );
    _subscriptions.add(
      _player.stream.duration.listen((value) {
        if (mounted) setState(() => _durationMs = value.inMilliseconds);
      }),
    );
    _subscriptions.add(
      _player.stream.completed.listen((value) {
        if (mounted && value) setState(() => _playing = false);
      }),
    );
    _subscriptions.add(
      _player.stream.error.listen((value) {
        if (value.isNotEmpty) _handlePlayerError(value);
      }),
    );
    _startDanmaku();
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bvid != widget.bvid || oldWidget.cid != widget.cid) {
      _switchVideo();
    }
    if (oldWidget.fullscreen != widget.fullscreen) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _controlsVisible = true;
      if (widget.fullscreen) {
        _scheduleHide();
      }
      _scheduleFullscreenMode(widget.fullscreen);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    if (widget.fullscreen) _scheduleFullscreenMode(false);
    _loadGeneration++;
    _danmakuGeneration++;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _danmakuSubscription?.cancel();
    _danmakuService.dispose();
    _danmakuBuffer.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  void _scheduleFullscreenMode(bool fullscreen) {
    Future<void>.delayed(Duration.zero, () {
      if (fullscreen && !mounted) return;
      unawaited(fullscreen ? _enterFullscreenMode() : _restoreFullscreenMode());
    });
  }

  Future<void> _enterFullscreenMode() async {
    if (Platform.isAndroid) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(true);
    }
  }

  Future<void> _restoreFullscreenMode() async {
    if (Platform.isAndroid) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.fullscreen && state == AppLifecycleState.resumed) {
      _showControls();
      _scheduleFullscreenMode(true);
    }
  }

  void _showControls() {
    if (!mounted || !widget.fullscreen) return;
    _hideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!mounted || !widget.fullscreen || !_controlsVisible) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !widget.fullscreen) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _toggleControls() {
    if (!widget.fullscreen) return;
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Future<void> _startDanmaku() async {
    final generation = ++_danmakuGeneration;
    final cid = widget.cid;
    final previous = _danmakuSubscription;
    _danmakuSubscription = null;
    if (previous != null) await previous.cancel();
    final history = await _danmakuService.history(cid);
    if (!mounted || generation != _danmakuGeneration || cid != widget.cid) {
      return;
    }
    _danmakuBuffer.addAll(history);
    _danmakuSubscription = _danmakuService
        .live(cid)
        .listen((item) => _danmakuBuffer.addAll([item]), onError: (_) {});
  }

  void _switchVideo() {
    _loadGeneration++;
    _danmakuGeneration++;
    unawaited(_danmakuSubscription?.cancel());
    _danmakuSubscription = null;
    _danmakuBuffer.clear();
    _source = null;
    _playData = null;
    _selectedQn = 0;
    _sourceIndex = 0;
    _videoUrls = [];
    _audioUrls = [];
    _positionMs = 0;
    _durationMs = 0;
    _playing = false;
    _buffering = false;
    _dragging = false;
    _retrying = false;
    setState(() {
      _loading = true;
      _error = null;
    });
    unawaited(_player.stop());
    unawaited(_startDanmaku());
    unawaited(_load());
  }

  Future<void> _load({int? qn}) async {
    final generation = ++_loadGeneration;
    final settings = context.read<SettingsStore>();
    final requested = qn ?? settings.defaultQuality;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<BiliApi>().playUrl(
        bvid: widget.bvid,
        cid: widget.cid,
        qn: requested,
      );
      if (!mounted || generation != _loadGeneration) return;
      final source = data.sourceFor(data.selectedQn);
      if (source == null) throw const BiliException(-1, '没有可用的播放地址');
      setState(() {
        _playData = data;
        _selectedQn = data.selectedQn;
        _loading = false;
      });
      await _openSource(source, generation);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _openSource(PlaySource source, int generation) async {
    if (generation != _loadGeneration) return;
    _source = source;
    _videoUrls = [
      source.videoUrl,
      ...source.backupVideoUrls,
    ].where((url) => url.isNotEmpty).toSet().toList();
    _audioUrls = [
      if (source.audioUrl != null) source.audioUrl!,
      ...source.backupAudioUrls,
    ].where((url) => url.isNotEmpty).toSet().toList();
    _sourceIndex = 0;
    await _playCurrent(generation);
  }

  Future<void> _playCurrent(int generation) async {
    if (!mounted || generation != _loadGeneration) return;
    if (_sourceIndex >= _videoUrls.length) {
      setState(() => _error = '没有可用的视频地址');
      return;
    }
    final video = _videoUrls[_sourceIndex];
    final source = _source;
    final headers = source?.headers ?? const <String, String>{};
    final platform = _player.platform;
    if (source?.isDash == true && platform is NativePlayer) {
      final referer = headers['Referer'] ?? BiliApi.referer;
      final userAgent = headers['User-Agent'] ?? BiliApi.userAgent;
      try {
        await platform.setProperty(
          'http-header-fields',
          'Referer: $referer,User-Agent: $userAgent',
        );
      } catch (_) {}
    }
    try {
      await _player.open(Media(video, httpHeaders: headers));
      if (!mounted || generation != _loadGeneration) return;
      if (source?.isDash == true &&
          _audioUrls.isNotEmpty &&
          platform is NativePlayer) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted || generation != _loadGeneration) return;
        try {
          await platform.command(['audio-add', _audioUrls.first, 'select']);
        } catch (_) {
          // Video without audio is still better than a failed playback.
        }
      }
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      if (_sourceIndex + 1 < _videoUrls.length) {
        _sourceIndex++;
        await _playCurrent(generation);
      } else {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _handlePlayerError(String message) async {
    if (!mounted || _retrying) return;
    if (_sourceIndex + 1 < _videoUrls.length) {
      _retrying = true;
      _sourceIndex++;
      await _playCurrent(_loadGeneration);
      _retrying = false;
      return;
    }
    setState(() => _error = '播放失败：$message');
  }

  void _selectQuality(int qn) {
    if (qn == _selectedQn) return;
    final data = _playData;
    if (data != null && data.sources.containsKey(qn)) {
      final source = data.sourceFor(qn);
      if (source != null) {
        final generation = ++_loadGeneration;
        setState(() {
          _selectedQn = qn;
          _loading = true;
          _error = null;
        });
        unawaited(_openSource(source, generation));
        return;
      }
    }
    _load(qn: qn);
  }

  void _togglePlay() {
    if (_playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seekTo(double fraction) {
    final duration = _durationMs;
    if (duration <= 0) return;
    final target = (fraction * duration).round();
    _player.seek(Duration(milliseconds: target));
  }

  void _setSpeed(double speed) {
    _player.setRate(speed);
    setState(() => _speed = speed);
  }

  void _exitFullscreen() {
    final callback = widget.onExitFullscreen;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final shownPosition = _dragging
        ? (_dragValue * _durationMs).round()
        : _positionMs;
    final progress = _durationMs <= 0
        ? 0.0
        : (shownPosition / _durationMs).clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final controlsVisible = !widget.fullscreen || _controlsVisible;
        return MouseRegion(
          cursor: widget.fullscreen && !_controlsVisible
              ? SystemMouseCursors.none
              : MouseCursor.defer,
          onHover: (_) {
            if (widget.fullscreen) _showControls();
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (widget.fullscreen && _controlsVisible) _showControls();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Video(
                      controller: _videoController,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                    ),
                    DanmakuOverlay(
                      buffer: _danmakuBuffer,
                      positionMs: _positionMs,
                      playing: _playing,
                      enabled: settings.danmakuEnabled,
                      opacity: settings.danmakuOpacity,
                      fontScale: settings.danmakuFontScale,
                      speed: settings.danmakuSpeed,
                      area: settings.danmakuArea,
                      stroke: settings.danmakuStroke,
                      showScroll: settings.danmakuShowScroll,
                      showTop: settings.danmakuShowTop,
                      showBottom: settings.danmakuShowBottom,
                    ),
                    _buildTopBar(compact, controlsVisible),
                    if (!_playing && !_loading && _error == null)
                      IgnorePointer(
                        ignoring: !controlsVisible,
                        child: AnimatedOpacity(
                          opacity: controlsVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: Center(
                            child: IconButton(
                              tooltip: '播放',
                              onPressed: _togglePlay,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                              icon: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: compact ? 42 : 56,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if ((_loading || _buffering) && _error == null)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    if (_error != null) _buildError(compact),
                    _buildBottomBar(
                      compact,
                      shownPosition,
                      progress,
                      controlsVisible,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(bool compact, bool controlsVisible) {
    final row = Row(
      children: [
        if (widget.fullscreen) ...[
          _controlIcon(
            tooltip: '退出全屏',
            icon: Icons.arrow_back,
            onPressed: _exitFullscreen,
            compact: compact,
          ),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 14,
              ),
            ),
          ),
        ] else
          const Spacer(),
        IconButton(
          tooltip: '弹幕设置',
          onPressed: () async {
            _cancelHideTimer();
            await showDanmakuSettingsSheet(context);
            _scheduleHide();
          },
          style: widget.fullscreen
              ? null
              : IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.34),
                ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
          ),
          icon: Icon(
            Icons.subtitles_outlined,
            color: Colors.white,
            size: compact ? 20 : 24,
          ),
        ),
        _QualityMenu(
          data: _playData,
          selectedQn: _selectedQn,
          onSelected: _selectQuality,
          onOpened: _cancelHideTimer,
          onCanceled: _scheduleHide,
          compact: compact,
          showBackground: !widget.fullscreen,
        ),
      ],
    );
    final content = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.62), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: widget.fullscreen ? SafeArea(bottom: false, child: row) : row,
    );
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        ignoring: !controlsVisible,
        child: AnimatedOpacity(
          opacity: controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: content,
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    bool compact,
    int shownPosition,
    double progress,
    bool controlsVisible,
  ) {
    final timeStyle = TextStyle(
      color: Colors.white,
      fontSize: compact ? 10 : 12,
    );
    final row = Row(
      children: [
        _controlIcon(
          tooltip: _playing ? '暂停' : '播放',
          icon: _playing ? Icons.pause : Icons.play_arrow,
          onPressed: _togglePlay,
          compact: compact,
        ),
        Text(formatDuration(shownPosition ~/ 1000), style: timeStyle),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: progress,
              onChangeStart: (value) {
                _cancelHideTimer();
                setState(() {
                  _dragging = true;
                  _dragValue = value;
                });
              },
              onChanged: (value) => setState(() => _dragValue = value),
              onChangeEnd: (value) {
                _seekTo(value);
                setState(() => _dragging = false);
                _scheduleHide();
              },
            ),
          ),
        ),
        Text(formatDuration(_durationMs ~/ 1000), style: timeStyle),
        PopupMenuButton<double>(
          tooltip: '播放速度',
          initialValue: _speed,
          onOpened: _cancelHideTimer,
          onCanceled: _scheduleHide,
          onSelected: (value) {
            _setSpeed(value);
            _scheduleHide();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 0.5, child: Text('0.5x')),
            PopupMenuItem(value: 0.75, child: Text('0.75x')),
            PopupMenuItem(value: 1.0, child: Text('1.0x')),
            PopupMenuItem(value: 1.25, child: Text('1.25x')),
            PopupMenuItem(value: 1.5, child: Text('1.5x')),
            PopupMenuItem(value: 2.0, child: Text('2.0x')),
          ],
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 8,
              vertical: compact ? 10 : 12,
            ),
            child: Text(
              '${_speed}x',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 10 : 12,
              ),
            ),
          ),
        ),
        if (widget.fullscreen)
          _controlIcon(
            tooltip: '退出全屏',
            icon: Icons.fullscreen_exit,
            onPressed: _exitFullscreen,
            compact: compact,
          )
        else if (widget.onFullscreen != null)
          _controlIcon(
            tooltip: '全屏',
            icon: Icons.fullscreen,
            onPressed: widget.onFullscreen,
            compact: compact,
          ),
      ],
    );
    final content = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.78)],
        ),
      ),
      padding: EdgeInsets.only(top: compact ? 6 : 10),
      child: widget.fullscreen ? SafeArea(top: false, child: row) : row,
    );
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !controlsVisible,
        child: AnimatedOpacity(
          opacity: controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: content,
        ),
      ),
    );
  }

  Widget _buildError(bool compact) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(compact ? 10 : 24),
        padding: EdgeInsets.all(compact ? 12 : 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              userMessageFor(_error!),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 12 : 14,
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            FilledButton(
              onPressed: () => _load(qn: _selectedQn),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool compact,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: compact ? 36 : 40,
        height: compact ? 36 : 40,
      ),
      icon: Icon(icon, color: Colors.white, size: compact ? 20 : 24),
    );
  }
}

class _QualityMenu extends StatelessWidget {
  const _QualityMenu({
    required this.data,
    required this.selectedQn,
    required this.onSelected,
    this.onOpened,
    this.onCanceled,
    this.compact = false,
    this.showBackground = false,
  });

  final PlayData? data;
  final int selectedQn;
  final ValueChanged<int> onSelected;
  final VoidCallback? onOpened;
  final VoidCallback? onCanceled;
  final bool compact;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final qualities = data?.qualities ?? const <VideoQuality>[];
    if (qualities.isEmpty) return const SizedBox.shrink();
    final selected = qualities.firstWhere(
      (quality) => quality.qn == selectedQn,
      orElse: () => qualities.first,
    );
    Widget child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 8,
        vertical: compact ? 10 : 12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected.label,
            style: TextStyle(color: Colors.white, fontSize: compact ? 10 : 12),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: Colors.white,
            size: compact ? 16 : 18,
          ),
        ],
      ),
    );
    if (showBackground) {
      child = Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: child,
      );
    }
    return PopupMenuButton<int>(
      tooltip: '画质',
      initialValue: selected.qn,
      onOpened: onOpened,
      onCanceled: onCanceled,
      onSelected: (value) {
        onSelected(value);
        onCanceled?.call();
      },
      itemBuilder: (context) => qualities
          .map(
            (quality) => PopupMenuItem<int>(
              value: quality.qn,
              child: Text(quality.label),
            ),
          )
          .toList(),
      child: child,
    );
  }
}
