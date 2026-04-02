import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/content_item.dart';
import '../models/kiosk_settings.dart';
import '../services/api_service.dart';
import '../services/enroll_service.dart';
import '../services/file_cache_service.dart';
import '../services/mdm_socket_service.dart';
import '../services/playback_bridge.dart';
import '../services/remote_control_server.dart';
import '../services/settings_service.dart';

class KioskController extends ChangeNotifier {
  KioskController({
    required SettingsService settingsService,
    required ApiService apiService,
    required FileCacheService fileCacheService,
  })  : _settingsService = settingsService,
        _apiService = apiService,
        _fileCacheService = fileCacheService;

  final SettingsService _settingsService;
  final ApiService _apiService;
  final FileCacheService _fileCacheService;
  final RemoteControlServer _remoteServer = RemoteControlServer();
  final PlaybackBridge _playbackBridge = PlaybackBridge.instance;
  final EnrollService _enrollService = EnrollService();

  KioskSettings _settings = KioskSettings.initial();
  List<ContentItem> _playlist = const [];
  int _currentIndex = 0;
  bool _bootstrapping = true;
  bool _loadingPlaylist = false;
  bool _enrolling = false;
  String? _error;
  DateTime? _lastRefreshAt;
  ContentItem? _overrideItem;
  bool _paused = false;
  bool _stopped = false;
  bool _muted = false;
  double _volume = 100;
  bool _shellRequested = false;
  int _pdfPage = 1;
  int _pdfPageTotal = 1;
  String _playMode = 'manual';
  Map<String, dynamic> _playbackPolicy = <String, dynamic>{
    'image_duration_sec': 15,
    'pdf_duration_sec': 20,
    'web_duration_sec': 20,
    'slide_duration_sec': 20,
    'video_max_duration_sec': 0,
    'audio_max_duration_sec': 0,
    'transition_delay_ms': 800,
    'error_skip_after_sec': 5,
    'loop_playlist': true,
  };
  Timer? _autoAdvanceTimer;

  MdmSocketService? _mdmSocketService;
  DateTime _startedAt = DateTime.now();
  bool _mdmConnected = false;
  String? _resolvedPlaylistCode;
  String? _resolvedFrom;
  String? _assignmentId;

  KioskSettings get settings => _settings;
  List<ContentItem> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get bootstrapping => _bootstrapping;
  bool get loadingPlaylist => _loadingPlaylist;
  bool get enrolling => _enrolling;
  String? get error => _error;
  DateTime? get lastRefreshAt => _lastRefreshAt;
  bool get paused => _paused;
  bool get stopped => _stopped;
  bool get muted => _muted;
  double get volume => _volume;
  bool get mdmConnected => _mdmConnected;
  String? get resolvedPlaylistCode => _resolvedPlaylistCode;
  String? get resolvedFrom => _resolvedFrom;
  String? get assignmentId => _assignmentId;
  bool get shellRequested => _shellRequested;
  String get playMode => _playMode;
  bool get autoPlayEnabled => _playMode == 'auto';
  Map<String, dynamic> get playbackPolicy => Map<String, dynamic>.from(_playbackPolicy);

  ContentItem? get currentItem {
    if (_stopped) return null;
    if (_overrideItem != null) return _overrideItem;
    if (_playlist.isEmpty) return null;
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return null;
    return _playlist[_currentIndex];
  }

  String get playbackState {
    if (_stopped) return 'stopped';
    if (_loadingPlaylist) return 'loading';
    if (_shellRequested && _paused) return 'paused';
    if (_shellRequested && currentItem != null) return 'playing';
    return currentItem == null ? 'idle' : 'ready';
  }

  Future<void> bootstrap() async {
    _bootstrapping = true;
    notifyListeners();

    _settings = await _settingsService.load();
    _startedAt = DateTime.now();

    if (_settings.deviceSerial.trim().isEmpty ||
        _settings.deviceName.trim().isEmpty) {
      final defaultSerial = _enrollService.buildDefaultSerial();
      final defaultName = _enrollService.buildDefaultDisplayName();
      _settings = _settings.copyWith(
        deviceSerial: _settings.deviceSerial.trim().isEmpty
            ? defaultSerial
            : _settings.deviceSerial,
        deviceName: _settings.deviceName.trim().isEmpty
            ? defaultName
            : _settings.deviceName,
      );
      await _settingsService.save(_settings);
    }

    await refreshPlaylist(useFallbackOnError: true, preserveCurrent: true);
    _playbackBridge.applyPlaybackConfig(
      playMode: _playMode,
      autoPlay: autoPlayEnabled,
      policy: _playbackPolicy,
    );
    await _restartRemoteServer();
    await _restartMdmSocket();

    _bootstrapping = false;
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  Future<void> saveSettings(KioskSettings settings) async {
    _settings = settings;
    await _settingsService.save(settings);
    await _restartRemoteServer();
    await _restartMdmSocket();
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  Future<void> enrollDevice({
    required String serverUrl,
    required String code,
    required String displayName,
    String? serial,
  }) async {
    final finalSerial = (serial ?? '').trim().isNotEmpty
        ? serial!.trim()
        : (_settings.deviceSerial.trim().isNotEmpty
        ? _settings.deviceSerial.trim()
        : _enrollService.buildDefaultSerial());

    final finalDisplayName = displayName.trim().isNotEmpty
        ? displayName.trim()
        : (_settings.deviceName.trim().isNotEmpty
        ? _settings.deviceName.trim()
        : _enrollService.buildDefaultDisplayName());

    _enrolling = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _enrollService.enrollDevice(
        serverUrl: serverUrl.trim(),
        code: code.trim(),
        serial: finalSerial,
        displayName: finalDisplayName,
      );

      _settings = _settings.copyWith(
        mdmEnabled: true,
        mdmServerUrl: result.mdmUrl.trim().isNotEmpty
            ? result.mdmUrl.trim()
            : serverUrl.trim(),
        mdmDeviceToken: result.deviceToken,
        deviceId: result.deviceId,
        deviceSerial: finalSerial,
        deviceName: finalDisplayName,
        enrollCode: code.trim(),
      );

      await _settingsService.save(_settings);
      await _restartMdmSocket();
      notifyListeners();
      unawaited(pushRuntimeNow());
    } finally {
      _enrolling = false;
      notifyListeners();
    }
  }

  Future<void> clearDeviceEnrollment() async {
    _settings = _settings.copyWith(
      deviceId: '',
      mdmDeviceToken: '',
      enrollCode: '',
      mdmEnabled: false,
    );
    await _settingsService.save(_settings);
    await _restartMdmSocket();
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  Future<void> refreshPlaylist({
    bool useFallbackOnError = false,
    bool preserveCurrent = true,
  }) async {
    _loadingPlaylist = true;
    _error = null;
    notifyListeners();

    final current = currentItem;
    final currentUrl = current?.url.trim() ?? '';
    final currentCode = current?.id.trim() ?? '';

    try {
      final hasServer = _settings.mdmServerUrl.trim().isNotEmpty;
      final hasToken = _settings.mdmDeviceToken.trim().isNotEmpty;
      final hasCode = _settings.playlistCode.trim().isNotEmpty;
      final hasDirectUrl = _settings.playlistUrl.trim().isNotEmpty;

      final result = (hasCode && hasServer)
          ? await _apiService.fetchPlaylist(_settings.buildPlaylistUrl())
          : (_settings.mdmEnabled && hasServer && hasToken)
          ? await _apiService.fetchResolvedPlaylist(
        serverUrl: _settings.mdmServerUrl,
        deviceToken: _settings.mdmDeviceToken,
      )
          : hasDirectUrl
          ? await _apiService.fetchPlaylist(_settings.playlistUrl.trim())
          : await _apiService.fetchPlaylist(_settings.buildPlaylistUrl());

      final items = result.items.where((e) => e.url.trim().isNotEmpty).toList();
      if (items.isEmpty) {
        throw Exception('Playlist trả về rỗng');
      }

      _resolvedPlaylistCode = result.code;
      _resolvedFrom = result.resolvedFrom;
      _assignmentId = result.assignmentId;
      _playlist = items;

      if (_currentIndex >= _playlist.length) {
        _currentIndex = 0;
      }

      if (preserveCurrent && current != null && _overrideItem == null) {
        final matchedIndex = _playlist.indexWhere(
              (e) =>
          (currentCode.isNotEmpty && e.id.trim() == currentCode) ||
              (currentUrl.isNotEmpty && e.url.trim() == currentUrl),
        );
        if (matchedIndex >= 0) {
          _currentIndex = matchedIndex;
        }
      }

      _lastRefreshAt = DateTime.now();
    } catch (e) {
      final raw = e.toString();
      if (raw.contains('404')) {
        _error =
        'Không tìm thấy playlist. Nếu đang dùng MDM thì thiết bị chưa được gán kịch bản phát; nếu đang dùng mã kịch bản thì mã chưa tồn tại.';
      } else if (raw.contains('401')) {
        _error = 'Thiếu hoặc sai bearer token của thiết bị.';
      } else {
        _error = raw;
      }

      if (useFallbackOnError) {
        _playlist = _apiService.demoPlaylist();
        _resolvedPlaylistCode = 'demo';
        _resolvedFrom = 'fallback';
        _assignmentId = null;
        if (_currentIndex >= _playlist.length) {
          _currentIndex = 0;
        }
        _lastRefreshAt = DateTime.now();
      }
    } finally {
      _loadingPlaylist = false;
      notifyListeners();
      unawaited(pushRuntimeNow());
    }
  }

  Future<void> _activateCurrentItem() async {
    _cancelAutoAdvance();
    final item = currentItem;
    if (item == null) return;

    _stopped = false;
    _paused = false;
    _shellRequested = true;

    if (item.type == ContentType.pdf) {
      _pdfPage = 1;
      _pdfPageTotal = _pdfPageTotal <= 0 ? 1 : _pdfPageTotal;
      await warmupCurrentPdfIfNeeded();
    }

    // QUAN TRỌNG:
    // Không gửi open_* qua bridge nữa.
    // Renderer sẽ tự rebuild theo currentItem mới.
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void next() {
    if (_playlist.isEmpty) return;
    _cancelAutoAdvance();
    _overrideItem = null;
    _currentIndex = (_currentIndex + 1) % _playlist.length;
    unawaited(_activateCurrentItem());
  }

  void previous() {
    if (_playlist.isEmpty) return;
    _cancelAutoAdvance();
    _overrideItem = null;
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    unawaited(_activateCurrentItem());
  }

  void jumpTo(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _cancelAutoAdvance();
    _overrideItem = null;
    _currentIndex = index;
    unawaited(_activateCurrentItem());
  }

  void openDirect(ContentItem item) {
    _cancelAutoAdvance();
    _overrideItem = item;
    _stopped = false;
    _paused = false;
    _shellRequested = true;
    _pdfPage = 1;
    _pdfPageTotal = 1;
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void stopPlayback() {
    _cancelAutoAdvance();
    _stopped = true;
    _paused = false;
    _shellRequested = false;
    _playbackBridge.send('stop');
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void pausePlayback() {
    if (currentItem == null) return;
    _cancelAutoAdvance();
    _stopped = false;
    _paused = true;
    _shellRequested = true;
    _playbackBridge.send('pause');
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void resumePlayback() {
    if (currentItem == null) return;
    _stopped = false;
    _paused = false;
    _shellRequested = true;
    _playbackBridge.send('resume');
    _rescheduleAutoAdvance();
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void setVolume(double value) {
    final next = value.clamp(0, 100).toDouble();
    _volume = next;
    if (_volume > 0 && _muted) {
      _muted = false;
    }
    _playbackBridge.setVolume(_volume);
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void setMuted(bool value) {
    _muted = value;
    _playbackBridge.setMuted(value);
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void toggleMute() => setMuted(!_muted);

  void onRendererCompleted() {
    _paused = false;
    notifyListeners();
    if (autoPlayEnabled && (currentItem?.autoNext ?? true)) {
      _scheduleNextAfterTransition();
    }
    unawaited(pushRuntimeNow());
  }

  void onRendererReady() {
    if (_stopped) {
      _stopped = false;
    }
    _rescheduleAutoAdvance();
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void requestShellOpen() {
    _shellRequested = true;
    if (_stopped) {
      _stopped = false;
    }
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void requestHome() {
    _cancelAutoAdvance();
    _shellRequested = false;
    _paused = false;
    _overrideItem = null;
    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  Future<void> warmupCurrentPdfIfNeeded() async {
    final item = currentItem;
    if (item == null || item.type != ContentType.pdf) return;
    try {
      await _fileCacheService.download(item.url);
    } catch (_) {}
  }

  Future<void> _restartRemoteServer() async {
    await _remoteServer.start(
      controller: this,
      port: _settings.remoteControlPort,
      token: _settings.remoteControlToken,
      enabled: _settings.remoteControlEnabled,
    );
  }

  Future<void> _restartMdmSocket() async {
    await _mdmSocketService?.stop();
    _mdmSocketService = null;
    _mdmConnected = false;

    if (!_settings.mdmEnabled ||
        _settings.mdmServerUrl.trim().isEmpty ||
        _settings.deviceId.trim().isEmpty ||
        _settings.mdmDeviceToken.trim().isEmpty) {
      notifyListeners();
      return;
    }

    _mdmSocketService = MdmSocketService(
      serverUrl: _settings.mdmServerUrl,
      deviceId: _settings.deviceId,
      deviceToken: _settings.mdmDeviceToken,
      runtimeIntervalSeconds: _settings.mdmRuntimeIntervalSeconds,
      onCommand: (action, payload) => handleRemoteCommand(action, payload),
      buildRuntimeSnapshot: runtimeSnapshot,
      onPlaybackConfig: applyPlaybackConfigFromServer,
    );

    await _mdmSocketService!.start();
    _mdmConnected = _mdmSocketService!.isConnected;
    notifyListeners();
  }

  Future<void> applyPlaybackConfigFromServer(Map<String, dynamic> config) async {
    final previousMode = _playMode;
    final mode = (config['play_mode']?.toString().trim().toLowerCase().isNotEmpty ?? false)
        ? config['play_mode'].toString().trim().toLowerCase()
        : ((config['auto_play'] == true) ? 'auto' : 'manual');
    final policy = config['policy'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(config['policy'] as Map<String, dynamic>)
        : (config['policy'] is Map
        ? Map<String, dynamic>.from(config['policy'] as Map)
        : <String, dynamic>{});
    _playMode = mode == 'auto' ? 'auto' : 'manual';
    _playbackPolicy = {
      ..._playbackPolicy,
      ...policy,
    };

    // Khi đang phát thủ công bằng openDirect thì currentItem là _overrideItem
    // với autoNext=false. Nếu bật lại auto-play mà vẫn giữ override này,
    // timer tự chuyển sẽ không chạy theo thời lượng playlist/policy.
    // Vì vậy cần quay về item trong playlist để auto-play hoạt động đúng.
    if (_playMode == 'auto' && _overrideItem != null) {
      final override = _overrideItem;
      final overrideUrl = override?.url.trim() ?? '';
      final overrideCode = override?.code.trim() ?? '';
      _overrideItem = null;
      if (_playlist.isNotEmpty) {
        final matchedIndex = _playlist.indexWhere((e) =>
        (overrideCode.isNotEmpty && e.code.trim() == overrideCode) ||
            (overrideUrl.isNotEmpty && e.url.trim() == overrideUrl));
        if (matchedIndex >= 0) {
          _currentIndex = matchedIndex;
        }
      }
    }

    _playbackBridge.applyPlaybackConfig(
      playMode: _playMode,
      autoPlay: autoPlayEnabled,
      policy: _playbackPolicy,
    );

    if (_playMode == 'auto') {
      if (!_shellRequested && currentItem != null) {
        await _activateCurrentItem();
      } else {
        _rescheduleAutoAdvance();
      }
    } else {
      _cancelAutoAdvance();
    }

    if (previousMode != _playMode || policy.isNotEmpty) {
      notifyListeners();
      unawaited(pushRuntimeNow());
      return;
    }

    notifyListeners();
  }

  int _policyInt(String key, int fallback) {
    final value = _playbackPolicy[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Duration _transitionDelay() => Duration(milliseconds: _policyInt('transition_delay_ms', 800));

  int _resolveAutoAdvanceSeconds(ContentItem item) {
    switch (item.type) {
      case ContentType.image:
        return item.durationConfigured ? item.durationSeconds : _policyInt('image_duration_sec', 15);
      case ContentType.pdf:
        return item.durationConfigured ? item.durationSeconds : _policyInt('pdf_duration_sec', 20);
      case ContentType.web:
        return item.durationConfigured ? item.durationSeconds : _policyInt('web_duration_sec', 20);
      case ContentType.slide:
        return item.durationConfigured ? item.durationSeconds : _policyInt('slide_duration_sec', 20);
      case ContentType.video:
        return item.durationConfigured ? item.durationSeconds : _policyInt('video_max_duration_sec', 0);
      case ContentType.audio:
        return item.durationConfigured ? item.durationSeconds : _policyInt('audio_max_duration_sec', 0);
      case ContentType.unknown:
        return 0;
    }
  }

  void _cancelAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  void _scheduleNextAfterTransition() {
    _cancelAutoAdvance();
    if (!autoPlayEnabled || _playlist.isEmpty || currentItem == null) return;
    _autoAdvanceTimer = Timer(_transitionDelay(), () {
      if (!_shellRequested || _paused || _stopped || !autoPlayEnabled) return;
      next();
    });
  }

  void _rescheduleAutoAdvance() {
    _cancelAutoAdvance();
    final item = currentItem;
    if (item == null || !autoPlayEnabled || !item.autoNext || _paused || _stopped || !_shellRequested) {
      return;
    }
    final seconds = _resolveAutoAdvanceSeconds(item);
    if (seconds <= 0) return;
    _autoAdvanceTimer = Timer(Duration(seconds: seconds), () {
      if (!_shellRequested || _paused || _stopped || !autoPlayEnabled) return;
      next();
    });
  }

  Map<String, dynamic> remoteSnapshot() {
    final item = currentItem;
    return {
      'ok': true,
      'device_id': _settings.deviceId,
      'device_name': _settings.deviceName,
      'device_serial': _settings.deviceSerial,
      'playlist_url': _settings.playlistUrl,
      'playlist_code': _resolvedPlaylistCode ?? _settings.playlistCode,
      'playlist_count': _playlist.length,
      'current_index': _currentIndex,
      'current_item': item?.toJson(),
      'playback_state': playbackState,
      'screen_state': _shellRequested ? 'player' : 'home',
      'muted': _muted,
      'volume': _volume.round(),
      'remote_control_port': _settings.remoteControlPort,
      'last_refresh_at': _lastRefreshAt?.toIso8601String(),
      'error': _error,
      'mdm_enabled': _settings.mdmEnabled,
      'mdm_server_url': _settings.mdmServerUrl,
      'mdm_connected': _mdmSocketService?.isConnected == true,
      'shell_requested': _shellRequested,
      'manual_mode': !autoPlayEnabled,
      'play_mode': _playMode,
      'auto_play': autoPlayEnabled,
      'playback_policy': Map<String, dynamic>.from(_playbackPolicy),
    };
  }

  Map<String, dynamic> runtimeSnapshot() {
    final item = currentItem;
    final uptimeSec = DateTime.now().difference(_startedAt).inSeconds;

    return {
      'kiosk_running': true,
      'kiosk_pid': null,
      'current_url': item?.url,
      'current_item': item?.toJson(),
      'content_type': item?.type.name ?? 'unknown',
      'screen_state': _shellRequested ? 'player' : 'home',
      'volume': _volume.round(),
      'muted': _muted,
      'app_version': 'kiosk_player_app',
      'uptime_sec': uptimeSec,
      'playback_state': playbackState,
      'play_mode': _playMode,
      'auto_play': autoPlayEnabled,
      'playback_policy': Map<String, dynamic>.from(_playbackPolicy),
      'raw': {
        'title': item?.title ?? _settings.deviceName,
        'subtitle': item?.subtitle ?? '',
        'content_type': item?.type.name ?? 'unknown',
        'screen_state': _shellRequested ? 'player' : 'home',
        'current_index': _currentIndex,
        'playlist_length': _playlist.length,
        'page': _pdfPage,
        'page_total': _pdfPageTotal,
        'position_sec': 0,
        'duration_sec': item?.durationSeconds ?? 0,
        'last_error': _error,
        'device_name': _settings.deviceName,
        'device_id': _settings.deviceId,
        'device_serial': _settings.deviceSerial,
        'playlist_code': _resolvedPlaylistCode ?? _settings.playlistCode,
        'resolved_from': _resolvedFrom,
        'assignment_id': _assignmentId,
        'manual_mode': !autoPlayEnabled,
        'play_mode': _playMode,
        'auto_play': autoPlayEnabled,
        'autoplay': autoPlayEnabled,
        'playlist_auto_play': autoPlayEnabled,
        'playback_policy': Map<String, dynamic>.from(_playbackPolicy),
      },
    };
  }

  DateTime? _lastRuntimePushAt;
  bool _runtimePushScheduled = false;

  Future<void> pushRuntimeNow() async {
    final now = DateTime.now();

    if (_lastRuntimePushAt != null &&
        now.difference(_lastRuntimePushAt!) < const Duration(seconds: 1)) {
      if (_runtimePushScheduled) return;

      _runtimePushScheduled = true;
      Future.delayed(const Duration(seconds: 1), () async {
        _runtimePushScheduled = false;
        await _pushRuntimeNowInternal();
      });
      return;
    }

    await _pushRuntimeNowInternal();
  }

  Future<void> _pushRuntimeNowInternal() async {
    try {
      _lastRuntimePushAt = DateTime.now();

      await _mdmSocketService?.pushRuntimeNow(
        sendViaWs: true,
        sendViaHttp: true,
      );

      _mdmConnected = _mdmSocketService?.isConnected == true;

      notifyListeners();
    } catch (e) {
      debugPrint('pushRuntimeNow error: $e');
    }
  }

  Future<Map<String, dynamic>> handleRemoteCommand(
      String action,
      Map<String, dynamic> payload,
      ) async {
    final normalized = _normalizeAction(action);

    try {
      switch (normalized) {
        case 'next':
          next();
          break;
        case 'prev':
          previous();
          break;
        case 'reload':
          await refreshPlaylist(preserveCurrent: true);
          break;
        case 'sync':
          await pushRuntimeNow();
          break;
        case 'home':
          requestHome();
          break;
        case 'pause':
          pausePlayback();
          break;
        case 'resume':
          resumePlayback();
          break;
        case 'play':
          if (_paused) {
            resumePlayback();
          } else if (currentItem != null) {
            await _activateCurrentItem();
          }
          break;
        case 'stop':
          stopPlayback();
          break;
        case 'mute':
          setMuted(true);
          break;
        case 'unmute':
          setMuted(false);
          break;
        case 'toggle_mute':
          toggleMute();
          break;
        case 'set_volume':
          setVolume(
            double.tryParse(payload['volume']?.toString() ?? '') ?? _volume,
          );
          break;
        case 'set_auto_play':
          await applyPlaybackConfigFromServer({
            'play_mode': (payload['enabled'] == true || payload['auto_play'] == true) ? 'auto' : 'manual',
            'auto_play': payload['enabled'] == true || payload['auto_play'] == true,
          });
          break;
        case 'volume_up':
          _stepVolume(payload, increase: true);
          break;
        case 'volume_down':
          _stepVolume(payload, increase: false);
          break;
        case 'page':
        case 'next_page':
        case 'prev_page':
          _changePdfPage(normalized, payload);
          break;
        case 'pdf_scroll_up':
        case 'pdf_scroll_down':
          _scrollPdf(normalized, payload);
          break;
        case 'open_web':
          _openUrlLike(payload, ContentType.web);
          break;
        case 'open_pdf':
          _openUrlLike(payload, ContentType.pdf);
          break;
        case 'open_image':
          _openUrlLike(payload, ContentType.image);
          break;
        case 'open_video':
          _openUrlLike(payload, ContentType.video);
          break;
        case 'open_audio':
          _openUrlLike(payload, ContentType.audio);
          break;
        case 'open_slide':
          _openUrlLike(payload, ContentType.slide);
          break;
        case 'play_playlist':
          final nextCode = payload['playlist_code']?.toString().trim() ?? '';
          final nextUrl = payload['playlist_url']?.toString().trim() ?? '';
          _settings = _settings.copyWith(
            playlistCode:
            nextCode.isNotEmpty ? nextCode : _settings.playlistCode,
            playlistUrl: nextUrl.isNotEmpty ? nextUrl : _settings.playlistUrl,
          );
          await _settingsService.save(_settings);
          await refreshPlaylist(preserveCurrent: false);
          if (currentItem != null) {
            await _activateCurrentItem();
          }
          break;
        default:
          return {
            'ok': false,
            'message': 'Unsupported action: $normalized',
            ...remoteSnapshot(),
          };
      }

      return {
        'ok': true,
        'message': 'Executed $normalized',
        ...remoteSnapshot(),
      };
    } catch (e) {
      return {
        'ok': false,
        'message': e.toString(),
        ...remoteSnapshot(),
      };
    }
  }

  String _normalizeAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'open_url':
        return 'open_web';
      case 'previous':
        return 'prev';
      case 'refresh':
        return 'reload';
      default:
        return action.trim().toLowerCase();
    }
  }

  void _changePdfPage(String action, Map<String, dynamic> payload) {
    final item = currentItem;
    if (item == null || item.type != ContentType.pdf) {
      throw Exception('Thiết bị hiện không phát nội dung PDF');
    }

    int delta;
    if (action == 'next_page') {
      delta = 1;
    } else if (action == 'prev_page') {
      delta = -1;
    } else {
      delta = int.tryParse(payload['delta']?.toString() ?? '') ?? 0;
    }
    if (delta == 0) return;

    _pdfPage += delta;
    if (_pdfPage < 1) _pdfPage = 1;

    _playbackBridge.send('page', {
      'page': _pdfPage,
      'delta': delta,
    });

    notifyListeners();
    unawaited(pushRuntimeNow());
  }

  void _openUrlLike(Map<String, dynamic> payload, ContentType fallbackType) {
    final url = payload['url']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw Exception('Thiếu URL');
    }

    final type = _detectType(url, fallbackType, payload['type']?.toString());
    final title = payload['title']?.toString().trim();
    final subtitle = payload['subtitle']?.toString().trim();
    final code = payload['code']?.toString().trim();
    final duration = int.tryParse(payload['durationSeconds']?.toString() ?? '');

    openDirect(
      ContentItem(
        id: (code == null || code.isEmpty)
            ? 'remote-${DateTime.now().millisecondsSinceEpoch}'
            : code,
        code: (code == null || code.isEmpty) ? '' : code,
        type: type,
        title: (title == null || title.isEmpty) ? 'Điều khiển từ xa' : title,
        subtitle: subtitle,
        url: url,
        durationSeconds: duration ?? 30,
        autoNext: false,
      ),
    );
  }

  void _stepVolume(Map<String, dynamic> payload, {required bool increase}) {
    final rawStep = payload['step']?.toString();
    final step = double.tryParse(rawStep ?? '') ?? 10;
    final nextValue = increase ? (_volume + step) : (_volume - step);
    setVolume(nextValue);
    _playbackBridge.send(increase ? 'volume_up' : 'volume_down', {
      'step': step,
      'volume': _volume.round(),
    });
  }

  void _scrollPdf(String action, Map<String, dynamic> payload) {
    final item = currentItem;
    if (item == null || item.type != ContentType.pdf) {
      throw Exception('Thiết bị hiện không phát nội dung PDF');
    }

    final rawStep = payload['step']?.toString();
    final step = int.tryParse(rawStep ?? '') ?? 1;
    _playbackBridge.send(action, {'step': step});
  }

  ContentType _detectType(String url, ContentType fallback, String? type) {
    final explicit = contentTypeFromString(type);
    if (explicit != ContentType.unknown) return explicit;

    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf')) return ContentType.pdf;
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp')) {
      return ContentType.image;
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv')) {
      return ContentType.video;
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac')) {
      return ContentType.audio;
    }
    return fallback;
  }

  @override
  void dispose() {
    _cancelAutoAdvance();
    _remoteServer.stop();
    _mdmSocketService?.stop();
    super.dispose();
  }
}