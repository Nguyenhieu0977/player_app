import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MdmDeviceApi {
  MdmDeviceApi({required this.serverUrl, required this.deviceToken});

  final String serverUrl;
  final String deviceToken;

  Uri _u(String path) {
    final base = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
    return Uri.parse('$base$path');
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $deviceToken',
  };

  Future<Map<String, dynamic>> fetchMyPlaylist() async {
    final res = await http.get(_u('/api/player/me/playlist'), headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Lấy playlist hiện hành thất bại: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    throw Exception('Response /api/player/me/playlist không hợp lệ');
  }



  Future<Map<String, dynamic>> fetchPlaybackConfig({required String deviceId}) async {
    final candidates = <Uri>[
      _u('/api/admin/windows/player/devices/$deviceId/playback-config'),
      _u('/api/admin/windows/devices/$deviceId/playback-config'),
    ];
    for (final uri in candidates) {
      try {
        final res = await http.get(uri, headers: _headers);
        if (res.statusCode < 200 || res.statusCode >= 300) continue;
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> pullCommands({int limit = 5}) async {
    final candidates = <Uri>[_u('/api/commands/pull?limit=$limit'), _u('/commands/pull?limit=$limit')];
    http.Response? lastRes;
    Object? lastErr;
    for (final uri in candidates) {
      try {
        final res = await http.get(uri, headers: _headers);
        lastRes = res;
        if (res.statusCode < 200 || res.statusCode >= 300) continue;
        final data = jsonDecode(res.body);
        if (data is! Map || data['commands'] is! List) return const [];
        return (data['commands'] as List)
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
      } catch (e) {
        lastErr = e;
        debugPrint('MDM pull exception @ $uri: $e');
      }
    }
    if (lastRes != null) throw Exception('Pull command thất bại: ${lastRes.statusCode} ${lastRes.body}');
    if (lastErr != null) throw Exception('Pull command exception: $lastErr');
    return const [];
  }

  Future<void> ackCommand({required String commandId, required bool ok, String status = 'done', String resultText = '', Map<String, dynamic> payload = const {}}) async {
    final reportBody = {
      'command_id': commandId,
      'ok': ok,
      'exit_code': ok ? 0 : 1,
      'stdout': ok ? resultText : jsonEncode(payload),
      'stderr': ok ? '' : (resultText.isNotEmpty ? resultText : jsonEncode(payload)),
    };
    final reportRes = await http.post(_u('/api/commands/report'), headers: _headers, body: jsonEncode(reportBody));
    if (reportRes.statusCode >= 200 && reportRes.statusCode < 300) return;
    final compatRes = await http.post(_u('/windows/commands/$commandId/ack'), headers: _headers, body: jsonEncode({'status': ok ? status : 'failed', 'ok': ok, 'result_text': resultText, 'payload': payload}));
    if (compatRes.statusCode < 200 || compatRes.statusCode >= 300) {
      throw Exception('ACK thất bại: report=${reportRes.statusCode} ${reportRes.body}; compat=${compatRes.statusCode} ${compatRes.body}');
    }
  }

  Future<void> pushRuntime({
    required bool kioskRunning,
    required String playbackState,
    int? kioskPid,
    String? currentUrl,
    int? volume,
    bool? muted,
    String? appVersion,
    int? uptimeSec,
    Map<String, dynamic> raw = const {},
    String? playlistCode,
    String? resolvedFrom,
    String? assignmentId,
    String? currentItemTitle,
    String? currentContentType,
  }) async {
    final mergedState = {
      ...raw,
      'kiosk_running': kioskRunning,
      'playback_state': playbackState,
      'kiosk_pid': kioskPid,
      'volume': volume,
      'muted': muted,
      'app_version': appVersion,
      'uptime_sec': uptimeSec,
      if (playlistCode != null) 'playlist_code': playlistCode,
      if (resolvedFrom != null) 'resolved_from': resolvedFrom,
      if (assignmentId != null) 'assignment_id': assignmentId,
      if (currentItemTitle != null) 'title': currentItemTitle,
      if (currentContentType != null) 'content_type': currentContentType,
      if (currentUrl != null) 'current_url': currentUrl,
    };

    final newBody = {
      'playlist_code': playlistCode,
      'assignment_id': assignmentId,
      'resolved_from': resolvedFrom,
      'current_item_title': currentItemTitle,
      'current_content_type': currentContentType,
      'content_source_url': currentUrl,
      'app_version': appVersion,
      'state': mergedState,
    };

    final legacyBody = {
      'kiosk_running': kioskRunning,
      'kiosk_pid': kioskPid,
      'current_url': currentUrl,
      'volume': volume,
      'muted': muted,
      'app_version': appVersion,
      'uptime_sec': uptimeSec,
      'playback_state': playbackState,
      'raw': mergedState,
    };

    http.Response? newRes;
    http.Response? legacyRes;

    try {
      newRes = await http.post(_u('/api/player/runtime'), headers: _headers, body: jsonEncode(newBody));
    } catch (e) {
      debugPrint('pushRuntime new endpoint error: $e');
    }

    try {
      legacyRes = await http.post(_u('/windows/runtime'), headers: _headers, body: jsonEncode(legacyBody));
    } catch (e) {
      debugPrint('pushRuntime legacy endpoint error: $e');
    }

    final newOk = newRes != null && newRes.statusCode >= 200 && newRes.statusCode < 300;
    final legacyOk = legacyRes != null && legacyRes.statusCode >= 200 && legacyRes.statusCode < 300;
    if (newOk || legacyOk) return;

    throw Exception('Push runtime thất bại: new=${newRes?.statusCode} ${newRes?.body}; legacy=${legacyRes?.statusCode} ${legacyRes?.body}');
  }
}
