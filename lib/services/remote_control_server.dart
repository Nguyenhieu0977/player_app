import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../state/kiosk_controller.dart';

class RemoteControlServer {
  HttpServer? _server;

  bool get isRunning => _server != null;

  Future<void> start({
    required KioskController controller,
    required int port,
    required String token,
    bool enabled = true,
  }) async {
    await stop();
    if (!enabled) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(
            (request) => _handle(request, controller, token),
        onError: (error, stack) => debugPrint('Remote server error: $error'),
      );
      debugPrint('Remote control server listening on port $port');
    } catch (e) {
      debugPrint('Cannot start remote control server on $port: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(
      HttpRequest request,
      KioskController controller,
      String token,
      ) async {
    request.response.headers.contentType = ContentType.json;
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, X-Kiosk-Token',
    );
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (!_isAuthorized(request, token)) {
      await _writeJson(request.response, HttpStatus.unauthorized, {
        'ok': false,
        'message': 'Unauthorized',
      });
      return;
    }

    final path = request.uri.path;

    if (request.method == 'GET' && path == '/status') {
      await _writeJson(
        request.response,
        HttpStatus.ok,
        controller.remoteSnapshot(),
      );
      return;
    }

    if (request.method == 'POST' && path == '/command') {
      Map<String, dynamic> body = {};
      try {
        final raw = await utf8.decoder.bind(request).join();
        if (raw.trim().isNotEmpty) {
          body = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        }
      } catch (_) {}

      final rawAction = body['action']?.toString() ?? '';
      final action = _normalizeAction(rawAction);
      final payload = body['payload'] is Map
          ? Map<String, dynamic>.from(body['payload'] as Map)
          : Map<String, dynamic>.from(body);

      final result = await controller.handleRemoteCommand(action, payload);

      await _writeJson(
        request.response,
        result['ok'] == true ? HttpStatus.ok : HttpStatus.badRequest,
        result,
      );
      return;
    }

    await _writeJson(request.response, HttpStatus.notFound, {
      'ok': false,
      'message': 'Not found',
    });
  }

  bool _isAuthorized(HttpRequest request, String token) {
    if (token.trim().isEmpty) return true;
    final headerToken = request.headers.value('x-kiosk-token') ??
        request.headers.value('authorization')?.replaceFirst('Bearer ', '');
    return headerToken == token;
  }

  String _normalizeAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'open_url':
        return 'open_web';
      case 'previous':
        return 'prev';
      case 'play':
        return 'resume';
      case 'refresh':
        return 'reload';
      default:
        return action.trim().toLowerCase();
    }
  }

  Future<void> _writeJson(
      HttpResponse response,
      int statusCode,
      Map<String, dynamic> body,
      ) async {
    response.statusCode = statusCode;
    response.write(jsonEncode(body));
    await response.close();
  }
}