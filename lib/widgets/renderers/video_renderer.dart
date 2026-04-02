import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/content_item.dart';
import '../../services/playback_bridge.dart';

class VideoRenderer extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onCompleted;

  const VideoRenderer({
    super.key,
    required this.item,
    required this.onCompleted,
  });

  @override
  State<VideoRenderer> createState() => _VideoRendererState();
}

class _VideoRendererState extends State<VideoRenderer> {
  late final Player _player;
  late final VideoController _videoController;

  StreamSubscription<bool>? _completedSub;
  StreamSubscription<PlaybackCommand>? _commandSub;

  bool _disposed = false;
  bool _stopping = false;
  bool _reloading = false;
  bool _openedOnce = false;

  int _openToken = 0;

  @override
  void initState() {
    super.initState();

    _player = Player();
    _videoController = VideoController(_player);

    _commandSub = PlaybackBridge.instance.stream.listen(_handleCommand);

    _completedSub = _player.stream.completed.listen((completed) {
      if (!completed) return;
      if (_disposed) return;
      if (_stopping) return;
      if (_reloading) return;
      if (!_openedOnce) return;

      widget.onCompleted();
    });

    unawaited(_open());
  }

  @override
  void didUpdateWidget(covariant VideoRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.item.url != widget.item.url) {
      _stopping = false;
      _openedOnce = false;
      unawaited(_open());
    }
  }

  Future<void> _open() async {
    if (_disposed) return;
    if (widget.item.url.trim().isEmpty) return;

    final int token = ++_openToken;
    _reloading = true;

    try {
      await _safePlayerCall(() => _player.open(Media(widget.item.url)));

      if (!_isCurrentToken(token)) return;

      await _safePlayerCall(() => _player.setPlaylistMode(PlaylistMode.none));

      if (!_isCurrentToken(token)) return;

      final double volume = PlaybackBridge.instance.muted
          ? 0
          : PlaybackBridge.instance.volume.toDouble();

      await _safePlayerCall(() => _player.setVolume(volume));

      if (!_isCurrentToken(token)) return;

      _openedOnce = true;
      _stopping = false;
    } finally {
      if (_isCurrentToken(token)) {
        _reloading = false;
      }
    }
  }

  bool _isCurrentToken(int token) {
    return !_disposed && token == _openToken;
  }

  Future<void> _handleCommand(PlaybackCommand command) async {
    if (_disposed) return;

    switch (command.type) {
      case 'pause':
        await _safePlayerCall(() => _player.pause());
        break;

      case 'resume':
        _stopping = false;
        await _safePlayerCall(() => _player.play());
        break;

      case 'stop':
        _stopping = true;
        await _safePlayerCall(() => _player.stop());
        break;

      case 'reload':
        _stopping = false;
        await _open();
        break;

      case 'set_muted':
        final bool value = command.payload['muted'] == true;
        final double volume = value
            ? 0
            : PlaybackBridge.instance.volume.toDouble();
        await _safePlayerCall(() => _player.setVolume(volume));
        break;

      case 'set_volume':
        final double volume =
            (command.payload['volume'] as num?)?.toDouble() ?? 100;
        if (!PlaybackBridge.instance.muted) {
          await _safePlayerCall(() => _player.setVolume(volume));
        }
        break;
    }
  }

  Future<void> _safePlayerCall(Future<void> Function() action) async {
    if (_disposed) return;

    try {
      await action();
    } catch (e) {
      if (_disposed) return;

      final String message = e.toString().toLowerCase();
      if (message.contains('has been disposed')) {
        return;
      }

      debugPrint('VideoRenderer error: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _openToken++;

    unawaited(_commandSub?.cancel());
    unawaited(_completedSub?.cancel());

    try {
      _player.dispose();
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Video(
        controller: _videoController,
        fit: BoxFit.contain,
        controls: NoVideoControls,
      ),
    );
  }
}