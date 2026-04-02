import 'dart:async';

class PlaybackCommand {
  final String type;
  final Map<String, dynamic> payload;

  const PlaybackCommand(this.type, [this.payload = const {}]);
}

class PlaybackBridge {
  PlaybackBridge._();

  static final PlaybackBridge instance = PlaybackBridge._();

  final StreamController<PlaybackCommand> _controller =
  StreamController<PlaybackCommand>.broadcast();

  Stream<PlaybackCommand> get stream => _controller.stream;

  bool muted = false;
  double volume = 100;

  /// Bật/tắt tự động phát nội dung tiếp theo khi nội dung hiện tại kết thúc.
  bool autoPlay = false;
  String playMode = 'manual';
  Map<String, dynamic> playbackPolicy = const <String, dynamic>{};

  /// Runtime hiện tại để player bridge/local bridge có thể đọc lại.
  final Map<String, dynamic> _runtime = <String, dynamic>{
    'playback_state': 'idle',
    'screen_state': 'home',
    'muted': false,
    'volume': 100.0,
    'page': 1,
    'page_total': 1,
    'position_sec': 0.0,
    'duration_sec': 0.0,
    'title': '',
    'content_type': '',
    'current_url': '',
    'current_item': null,
    'auto_play': false,
    'autoplay': false,
    'playlist_auto_play': false,
    'play_mode': 'manual',
    'playback_policy': <String, dynamic>{},
  };

  Map<String, dynamic> get runtime => Map<String, dynamic>.from(_runtime);

  void send(String type, [Map<String, dynamic> payload = const {}]) {
    if (!_controller.isClosed) {
      _controller.add(PlaybackCommand(type, payload));
    }
  }

  void setVolume(double value) {
    volume = value.clamp(0, 100).toDouble();
    _runtime['volume'] = volume;

    if (volume > 0 && muted) {
      muted = false;
      _runtime['muted'] = false;
      send('set_muted', {'muted': false});
    }

    send('set_volume', {'volume': volume.round()});
    reportState('volume_changed', {
      'volume': volume,
      'muted': muted,
    });
  }

  void setMuted(bool value) {
    muted = value;
    _runtime['muted'] = muted;
    send('set_muted', {'muted': muted});
    reportState('muted_changed', {
      'muted': muted,
      'volume': volume,
    });
  }

  void setAutoPlay(bool value) {
    autoPlay = value;
    playMode = value ? 'auto' : 'manual';
    _runtime['auto_play'] = value;
    _runtime['autoplay'] = value;
    _runtime['playlist_auto_play'] = value;
    _runtime['play_mode'] = playMode;

    send('set_auto_play', {
      'enabled': value,
      'auto_play': value,
    });

    reportState('auto_play_changed', {
      'auto_play': value,
      'autoplay': value,
      'playlist_auto_play': value,
    });
  }

  void applyPlaybackConfig({String? playMode, bool? autoPlay, Map<String, dynamic>? policy}) {
    if (playMode != null && playMode.trim().isNotEmpty) {
      this.playMode = playMode.trim().toLowerCase();
      _runtime['play_mode'] = this.playMode;
    }
    if (autoPlay != null) {
      this.autoPlay = autoPlay;
      _runtime['auto_play'] = autoPlay;
      _runtime['autoplay'] = autoPlay;
      _runtime['playlist_auto_play'] = autoPlay;
      _runtime['play_mode'] = autoPlay ? 'auto' : (_runtime['play_mode']?.toString() ?? this.playMode);
    }
    if (policy != null) {
      playbackPolicy = Map<String, dynamic>.from(policy);
      _runtime['playback_policy'] = Map<String, dynamic>.from(policy);
    }
    reportState('playback_config_changed', runtime);
  }

  void updateRuntime({
    String? playbackState,
    String? screenState,
    bool? muted,
    double? volume,
    int? page,
    int? pageTotal,
    double? positionSec,
    double? durationSec,
    String? title,
    String? contentType,
    String? currentUrl,
    Map<String, dynamic>? currentItem,
    bool? autoPlay,
    String? playMode,
    Map<String, dynamic>? playbackPolicy,
  }) {
    if (playbackState != null) _runtime['playback_state'] = playbackState;
    if (screenState != null) _runtime['screen_state'] = screenState;
    if (muted != null) _runtime['muted'] = muted;
    if (volume != null) _runtime['volume'] = volume;
    if (page != null) _runtime['page'] = page;
    if (pageTotal != null) _runtime['page_total'] = pageTotal;
    if (positionSec != null) _runtime['position_sec'] = positionSec;
    if (durationSec != null) _runtime['duration_sec'] = durationSec;
    if (title != null) _runtime['title'] = title;
    if (contentType != null) _runtime['content_type'] = contentType;
    if (currentUrl != null) _runtime['current_url'] = currentUrl;
    if (currentItem != null) _runtime['current_item'] = currentItem;
    if (autoPlay != null) {
      this.autoPlay = autoPlay;
      this.playMode = autoPlay ? 'auto' : 'manual';
      _runtime['auto_play'] = autoPlay;
      _runtime['autoplay'] = autoPlay;
      _runtime['playlist_auto_play'] = autoPlay;
      _runtime['play_mode'] = this.playMode;
    }
    if (playMode != null && playMode.trim().isNotEmpty) {
      this.playMode = playMode.trim().toLowerCase();
      _runtime['play_mode'] = this.playMode;
    }
    if (playbackPolicy != null) {
      this.playbackPolicy = Map<String, dynamic>.from(playbackPolicy);
      _runtime['playback_policy'] = Map<String, dynamic>.from(playbackPolicy);
    }
  }

  void markContentOpened({
    required String contentType,
    required String title,
    required String url,
    Map<String, dynamic>? currentItem,
  }) {
    updateRuntime(
      playbackState: 'loading',
      screenState: 'player',
      title: title,
      contentType: contentType,
      currentUrl: url,
      currentItem: currentItem ??
          <String, dynamic>{
            'title': title,
            'url': url,
            'type': contentType,
          },
      page: 1,
      pageTotal: 1,
      positionSec: 0,
      durationSec: 0,
    );

    reportState('content_opened', runtime);
  }

  void markPlaybackReady() {
    updateRuntime(
      playbackState: 'playing',
      screenState: 'player',
    );
    reportState('playback_ready', runtime);
  }

  void markPaused() {
    updateRuntime(playbackState: 'paused');
    reportState('paused', runtime);
  }

  void markResumed() {
    updateRuntime(playbackState: 'playing');
    reportState('resumed', runtime);
  }

  void markStopped() {
    updateRuntime(
      playbackState: 'stopped',
      positionSec: 0,
    );
    reportState('stopped', runtime);
  }

  void markHome() {
    updateRuntime(
      playbackState: 'idle',
      screenState: 'home',
      positionSec: 0,
      durationSec: 0,
    );
    reportState('home', runtime);
  }

  void markPdfPage({
    required int page,
    int? pageTotal,
  }) {
    updateRuntime(
      page: page,
      pageTotal: pageTotal,
      playbackState: 'ready',
      screenState: 'player',
    );
    reportState('page_changed', runtime);
  }

  void markCompleted({
    required String contentType,
    String? title,
    String? url,
  }) {
    updateRuntime(
      playbackState: 'stopped',
      contentType: contentType,
      title: title,
      currentUrl: url,
    );

    reportState('completed', {
      ...runtime,
      'content_type': contentType,
      if (title != null) 'title': title,
      if (url != null) 'current_url': url,
      'auto_play': autoPlay,
      'autoplay': autoPlay,
      'playlist_auto_play': autoPlay,
    });
  }

  void reportState(String type, [Map<String, dynamic> payload = const {}]) {
    send('report:$type', payload);
  }

  void dispose() {
    _controller.close();
  }
}