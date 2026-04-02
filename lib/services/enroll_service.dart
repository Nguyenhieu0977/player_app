import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class EnrollResult {
  const EnrollResult({
    required this.deviceId,
    required this.deviceToken,
    required this.mdmUrl,
  });

  final String deviceId;
  final String deviceToken;
  final String mdmUrl;

  factory EnrollResult.fromJson(Map<String, dynamic> json) {
    return EnrollResult(
      deviceId: json['device_id']?.toString() ?? '',
      deviceToken: json['device_token']?.toString() ?? '',
      mdmUrl: json['mdm_url']?.toString() ?? '',
    );
  }
}

class EnrollService {
  Future<EnrollResult> enrollDevice({
    required String serverUrl,
    required String code,
    required String serial,
    required String displayName,
  }) async {
    final base = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    final platform = _platformName();
    final uri = Uri.parse('$base/${_enrollPathForPlatform(platform)}');

    final res = await http.post(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'code': code,
        'serial': serial,
        'display_name': displayName,
        'os_version': _osVersion(),
        'platform': platform,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = 'Enroll thất bại: ${res.statusCode}';
      try {
        final data = jsonDecode(res.body);
        if (data is Map && data['detail'] != null) {
          message = data['detail'].toString();
        } else if (res.body.trim().isNotEmpty) {
          message = res.body;
        }
      } catch (_) {
        if (res.body.trim().isNotEmpty) {
          message = res.body;
        }
      }
      throw Exception(message);
    }

    final data = jsonDecode(res.body);
    if (data is! Map) {
      throw Exception('Dữ liệu enroll không hợp lệ');
    }

    final result = EnrollResult.fromJson(Map<String, dynamic>.from(data));
    if (result.deviceId.trim().isEmpty || result.deviceToken.trim().isEmpty) {
      throw Exception('Server không trả về device_id hoặc device_token');
    }

    return result;
  }

  String buildDefaultSerial() {
    final host = _hostName();
    final prefix = Platform.isAndroid ? 'AND' : Platform.isWindows ? 'WIN' : 'RPI';
    if (host.isNotEmpty) {
      return '$prefix-$host';
    }
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}';
  }

  String buildDefaultDisplayName() {
    final host = _hostName();
    if (host.isNotEmpty) return host;
    if (Platform.isAndroid) return 'ANDROID-KIOSK';
    if (Platform.isWindows) return 'WINDOWS-KIOSK';
    return 'RPI-KIOSK';
  }

  static String _hostName() {
    final envName =
        Platform.environment['COMPUTERNAME'] ??
            Platform.environment['HOSTNAME'] ??
            '';
    if (envName.trim().isNotEmpty) return envName.trim();

    try {
      return Platform.localHostname.trim();
    } catch (_) {
      return '';
    }
  }

  static String _osVersion() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unknown';
    }
  }

  static String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return 'rpi';
  }

  static String _enrollPathForPlatform(String platform) {
    switch (platform) {
      case 'android':
        return 'enroll/android';
      case 'windows':
        return 'enroll/windows';
      default:
        return 'enroll/pi';
    }
  }
}
