import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import './state/kiosk_controller.dart';

HttpServer? _bridgeServer;

Future<void> startBridge(KioskController controller) async {
  await _bridgeServer?.close(force: true);

  _bridgeServer = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    18181,
  );

  debugPrint('Bridge server running at http://127.0.0.1:18181');

  await for (final request in _bridgeServer!) {
    try {
      final path = request.uri.path;
      debugPrint('REQ: ${request.method} $path');

      if (path == '/api/control/ping') {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true}))
          ..close();
        continue;
      }

      if (path == '/api/control/status') {
        final status = controller.remoteSnapshot();
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(status))
          ..close();
        continue;
      }

      if (path == '/api/control/command') {
        final body = await utf8.decoder.bind(request).join();
        debugPrint('COMMAND RAW: $body');

        Map<String, dynamic> data = {};
        try {
          data = Map<String, dynamic>.from(jsonDecode(body) as Map);
        } catch (e) {
          debugPrint('JSON ERROR: $e');
        }

        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true}))
          ..close();

        Future.microtask(() async {
          try {
            await handleCommand(data, controller);
          } catch (e, st) {
            debugPrint('COMMAND ERROR: $e');
            debugPrint('$st');
          }
        });

        continue;
      }

      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'ok': false, 'error': 'not_found'}))
        ..close();
    } catch (e, st) {
      debugPrint('SERVER ERROR: $e');
      debugPrint('$st');
      try {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': false, 'error': e.toString()}))
          ..close();
      } catch (_) {}
    }
  }
}

Future<void> handleCommand(
    Map<String, dynamic> data,
    KioskController controller,
    ) async {
  final rawAction = data['action']?.toString().trim().toLowerCase() ?? '';
  final action = _normalizeAction(rawAction);
  final payload =
      (data['payload'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

  debugPrint('ACTION: $action | PAYLOAD: $payload');

  await controller.handleRemoteCommand(action, payload);
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