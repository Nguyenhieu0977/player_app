import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'mdm_device_api.dart';

typedef MdmCommandHandler = Future<Map<String, dynamic>> Function(
    String action,
    Map<String, dynamic> payload,
    );

typedef RuntimeSnapshotBuilder = Map<String, dynamic> Function();
typedef PlaybackConfigHandler = Future<void> Function(Map<String, dynamic> config);

class MdmSocketService {
  MdmSocketService({
    required this.serverUrl,
    required this.deviceId,
    required this.deviceToken,
    required this.runtimeIntervalSeconds,
    required this.onCommand,
    required this.buildRuntimeSnapshot,
    required this.onPlaybackConfig,
  }) : _deviceApi = MdmDeviceApi(
    serverUrl: serverUrl,
    deviceToken: deviceToken,
  );

  final String serverUrl;
  final String deviceId;
  final String deviceToken;
  final int runtimeIntervalSeconds;
  final MdmCommandHandler onCommand;
  final RuntimeSnapshotBuilder buildRuntimeSnapshot;
  final PlaybackConfigHandler onPlaybackConfig;

  final MdmDeviceApi _deviceApi;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _runtimeTimer;
  Timer? _reconnectTimer;
  Timer? _pollTimer;

  final Map<String, DateTime> _handledCommands = <String, DateTime>{};

  bool _started = false;
  bool _disposed = false;
  bool _connecting = false;
  int _reconnectAttempt = 0;

  bool get isConnected => _socket != null;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _disposed = false;

    await _connect();
    _startRuntimeTicker();
    _startPollTicker();
  }

  Future<void> stop() async {
    _started = false;
    _disposed = true;

    _runtimeTimer?.cancel();
    _runtimeTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _pollTimer?.cancel();
    _pollTimer = null;

    await _sub?.cancel();
    _sub = null;

    try {
      await _socket?.close();
    } catch (_) {}

    _socket = null;
  }

  Uri _wsUri() {
    final base = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    final uri = Uri.parse(base);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';

    return uri.replace(
      scheme: scheme,
      path: '/api/ws/devices/$deviceId',
      queryParameters: <String, String>{
        if (deviceToken.trim().isNotEmpty) 'token': deviceToken.trim(),
      },
    );
  }

  Future<void> _connect() async {
    if (_disposed || _connecting) return;
    _connecting = true;

    try {
      final uri = _wsUri();
      debugPrint('MDM WS connect: $uri');

      final socket =
      await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 12));

      debugPrint('✅ WS CONNECTED SUCCESS');

      _socket = socket;
      _reconnectAttempt = 0;

      _sub = socket.listen(
            (dynamic data) {
          debugPrint('📥 WS RAW: $data');
          unawaited(_onMessage(data));
        },
        onDone: () {
          debugPrint('❌ WS CLOSED');
          _onClosed();
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('❌ WS ERROR: $error');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      await _sendJson(<String, dynamic>{
        'type': 'device_hello',
        'device_id': deviceId,
        'role': 'kiosk_player_app',
        'ts': DateTime.now().toUtc().toIso8601String(),
      });

      await pushRuntimeNow(sendViaWs: true, sendViaHttp: true);
    } catch (e, st) {
      debugPrint('❌ WS connect failed: $e');
      debugPrint('$st');

      try {
        await _socket?.close();
      } catch (_) {}

      _socket = null;
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onClosed() {
    debugPrint('MDM WS closed');
    _socket = null;
    _sub?.cancel();
    _sub = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || !_started) return;
    if (_reconnectTimer?.isActive == true) return;

    _socket = null;
    _sub?.cancel();
    _sub = null;

    _reconnectAttempt += 1;
    final int seconds = _computeBackoffSeconds(_reconnectAttempt);
    debugPrint('MDM WS reconnect in ${seconds}s');

    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      _reconnectTimer = null;
      await _connect();
    });
  }

  int _computeBackoffSeconds(int attempt) {
    if (attempt <= 1) return 2;
    if (attempt == 2) return 4;
    if (attempt == 3) return 6;
    if (attempt == 4) return 10;
    return 15;
  }

  void _startPollTicker() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await pollCommandsNow();
    });
  }

  Future<void> pollCommandsNow() async {
    try {
      final List<dynamic> cmds = await _deviceApi.pullCommands(limit: 5);

      if (cmds.isEmpty) return;

      for (final dynamic raw in cmds) {
        Map<String, dynamic> cmd = <String, dynamic>{};

        if (raw is Map) {
          raw.forEach((dynamic k, dynamic v) => cmd[k.toString()] = v);
        } else if (raw.runtimeType.toString() == 'DeviceCommandItem') {
          cmd = <String, dynamic>{
            'id': raw.id,
            'type': raw.type,
            'payload': raw.payload,
          };
        } else {
          debugPrint('Invalid command item: $raw');
          continue;
        }

        final String commandId = (cmd['id'] ?? '').toString();
        if (commandId.isEmpty || _shouldSkipCommand(commandId)) {
          continue;
        }
        _rememberCommand(commandId);

        final Map<String, dynamic> payload = _mapFromDynamic(cmd['payload']);
        final Map<String, dynamic> extracted = _extractActionAndPayload(
          cmd['type']?.toString() ?? '',
          payload,
        );

        final String action = extracted['action']?.toString() ?? '';
        final Map<String, dynamic> finalPayload = _mapFromDynamic(extracted['payload']);

        if (action.isEmpty) continue;

        debugPrint('📥 POLL CMD: $cmd');

        final Map<String, dynamic> result = await onCommand(action, finalPayload);

        await _deviceApi.ackCommand(
          commandId: commandId,
          ok: result['ok'] == true,
          status: result['ok'] == true ? 'done' : 'failed',
          resultText: result['message']?.toString() ?? '',
          payload: <String, dynamic>{
            'action': action,
            'runtime': buildRuntimeSnapshot(),
          },
        );
      }
    } catch (e, st) {
      debugPrint('❌ pollCommandsNow error: $e');
      debugPrint('$st');
    }

    _handledCommands.removeWhere((String key, DateTime value) {
      return DateTime.now().difference(value).inMinutes > 30;
    });
  }

  Future<void> _onMessage(dynamic data) async {
    debugPrint('📥 WS MESSAGE: $data');

    try {
      final String text = data is String ? data : utf8.decode(data as List<int>);
      final dynamic decoded = jsonDecode(text);
      if (decoded is! Map) return;

      final Map<String, dynamic> map = _mapFromDynamic(decoded);
      final String type = (map['type'] ?? '').toString().trim().toLowerCase();

      if (type == 'hello') {
        try {
          final config = await _deviceApi.fetchPlaybackConfig(deviceId: deviceId);
          if (config.isNotEmpty) {
            await onPlaybackConfig(config);
          }
        } catch (_) {}
        await pushRuntimeNow(sendViaWs: true, sendViaHttp: false);
        await pollCommandsNow();
        return;
      }

      if (type == 'player_config_sync' || type == 'player_config_updated') {
        await onPlaybackConfig(_mapFromDynamic(map['payload']));
        await pushRuntimeNow(sendViaWs: true, sendViaHttp: true);
        return;
      }

      if (type == 'ping' || type == 'tick') {
        await _sendJson(<String, dynamic>{
          'type': 'pong',
          'target': 'device',
          'device_id': deviceId,
          'ts': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      }

      String commandId = '';
      String action = '';
      Map<String, dynamic> payload = <String, dynamic>{};

      if (type == 'command' && map['command'] is Map) {
        final Map<String, dynamic> cmd = _mapFromDynamic(map['command']);
        commandId = (cmd['id'] ?? '').toString();
        final String commandType = (cmd['type'] ?? '').toString();

        final Map<String, dynamic> extracted = _extractActionAndPayload(
          commandType,
          _mapFromDynamic(cmd['payload']),
        );

        action = (extracted['action'] ?? '').toString();
        payload = _mapFromDynamic(extracted['payload']);
      } else if (type == 'player_command') {
        commandId = (map['id'] ?? '').toString();
        final Map<String, dynamic> extracted = _extractActionAndPayload(
          'player_command',
          _mapFromDynamic(map['payload']),
        );
        action = (extracted['action'] ?? '').toString();
        payload = _mapFromDynamic(extracted['payload']);
      } else {
        action = _normalizeAction(map['action']?.toString() ?? '');
        payload = _mapFromDynamic(map['payload']);
      }

      if (action.isEmpty) return;
      if (commandId.isNotEmpty && _shouldSkipCommand(commandId)) return;
      if (commandId.isNotEmpty) _rememberCommand(commandId);

      final Map<String, dynamic> result = await onCommand(action, payload);

      if (commandId.trim().isNotEmpty && deviceToken.trim().isNotEmpty) {
        await _deviceApi.ackCommand(
          commandId: commandId,
          ok: result['ok'] == true,
          status: result['ok'] == true ? 'done' : 'failed',
          resultText: result['message']?.toString() ?? '',
          payload: <String, dynamic>{
            'action': action,
            'runtime': buildRuntimeSnapshot(),
          },
        );
      }

      await pushRuntimeNow(sendViaWs: true, sendViaHttp: true);
    } catch (e, st) {
      debugPrint('MDM WS parse/process error: $e');
      debugPrint('$st');
    }
  }

  Map<String, dynamic> _extractActionAndPayload(
      String commandType,
      Map<String, dynamic> commandPayload,
      ) {
    final String type = commandType.trim().toLowerCase();

    if (type == 'player_command') {
      String innerAction = commandPayload['action']?.toString() ?? '';
      Map<String, dynamic> innerPayload = _mapFromDynamic(commandPayload['payload']);

      if (_normalizeAction(innerAction) == 'player') {
        innerAction = innerPayload['action']?.toString() ?? '';
        innerPayload = _mapFromDynamic(innerPayload['payload']);
      }

      return <String, dynamic>{
        'action': _normalizeAction(innerAction),
        'payload': innerPayload,
      };
    }

    return <String, dynamic>{
      'action': _normalizeAction(commandType),
      'payload': commandPayload,
    };
  }

  void _startRuntimeTicker() {
    _runtimeTimer?.cancel();
    _runtimeTimer = Timer.periodic(
      Duration(seconds: runtimeIntervalSeconds <= 0 ? 20 : runtimeIntervalSeconds),
          (_) async {
        try {
          await pushRuntimeNow(sendViaWs: true, sendViaHttp: true);
        } catch (e) {
          debugPrint('MDM WS periodic runtime failed: $e');
        }
      },
    );
  }

  Future<void> pushRuntimeNow({
    bool sendViaWs = true,
    bool sendViaHttp = true,
  }) async {
    final Map<String, dynamic> runtime = buildRuntimeSnapshot();

    if (sendViaWs && _socket != null) {
      await _sendJson(<String, dynamic>{
        'type': 'runtime',
        'device_id': deviceId,
        'payload': runtime,
      });
    }

    if (sendViaHttp && deviceToken.trim().isNotEmpty) {
      await _deviceApi.pushRuntime(
        kioskRunning: runtime['kiosk_running'] == true,
        playbackState: runtime['playback_state']?.toString() ?? 'idle',
        kioskPid: _asInt(runtime['kiosk_pid']),
        currentUrl: runtime['current_url']?.toString(),
        volume: _asInt(runtime['volume']),
        muted: runtime['muted'] == true,
        appVersion: runtime['app_version']?.toString(),
        uptimeSec: _asInt(runtime['uptime_sec']),
        raw: runtime['raw'] is Map
            ? <String, dynamic>{
          for (final MapEntry<dynamic, dynamic> entry
          in (runtime['raw'] as Map<dynamic, dynamic>).entries)
            entry.key.toString(): entry.value,
        }
            : <String, dynamic>{},
      );
    }
  }

  Future<void> _sendJson(Map<String, dynamic> data) async {
    final WebSocket? socket = _socket;
    if (socket == null) return;
    socket.add(jsonEncode(data));
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Map<String, dynamic> _mapFromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          entry.key.toString(): entry.value,
      };
    }
    return <String, dynamic>{};
  }

  bool _shouldSkipCommand(String commandId) {
    final DateTime? last = _handledCommands[commandId];
    if (last == null) return false;
    return DateTime.now().difference(last).inMinutes < 10;
  }

  void _rememberCommand(String commandId) {
    _handledCommands[commandId] = DateTime.now();
  }

  String _normalizeAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'open_url':
        return 'open_web';
      case 'previous':
        return 'prev';
      case 'play':
        return 'play';
      case 'refresh':
      case 'refresh_player':
        return 'reload';
      case 'mute_audio':
      case 'mute_all':
        return 'mute';
      case 'unmute_audio':
      case 'unmute_all':
        return 'unmute';
      case 'play_playlist':
      case 'play_background_music':
        return 'play_playlist';
      case 'play_welcome_video':
        return 'open_video';
      case 'open_schedule':
        return 'open_pdf';
      default:
        return action.trim().toLowerCase();
    }
  }
}
