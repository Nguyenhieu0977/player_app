class KioskSettings {
  final String playlistUrl;
  final String playlistCode;
  final String deviceId;
  final String deviceName;
  final String deviceSerial;
  final String enrollCode;
  final int refreshIntervalSeconds;
  final bool autoFullscreen;
  final bool alwaysOnTop;
  final bool remoteControlEnabled;
  final int remoteControlPort;
  final String remoteControlToken;
  final bool mdmEnabled;
  final String mdmServerUrl;
  final String mdmDeviceToken;
  final int mdmRuntimeIntervalSeconds;

  const KioskSettings({
    required this.playlistUrl,
    required this.playlistCode,
    required this.deviceId,
    required this.deviceName,
    required this.deviceSerial,
    required this.enrollCode,
    required this.refreshIntervalSeconds,
    required this.autoFullscreen,
    required this.alwaysOnTop,
    required this.remoteControlEnabled,
    required this.remoteControlPort,
    required this.remoteControlToken,
    required this.mdmEnabled,
    required this.mdmServerUrl,
    required this.mdmDeviceToken,
    required this.mdmRuntimeIntervalSeconds,
  });

  factory KioskSettings.initial() {
    return const KioskSettings(
      playlistUrl: 'https://raw.githubusercontent.com/vega/vega/main/docs/data/movies.json',
      playlistCode: '',
      deviceId: '',
      deviceName: 'Màn hình trung tâm',
      deviceSerial: '',
      enrollCode: '',
      refreshIntervalSeconds: 60,
      autoFullscreen: true,
      alwaysOnTop: true,
      remoteControlEnabled: true,
      remoteControlPort: 9527,
      remoteControlToken: 'k7-demo-token',
      mdmEnabled: false,
      mdmServerUrl: 'http://192.168.1.216',
      mdmDeviceToken: '',
      mdmRuntimeIntervalSeconds: 20,
    );
  }

  String normalizeServerUrl() {
    final raw = mdmServerUrl.trim();
    if (raw.isEmpty) return '';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String buildPlaylistUrl() {
    final base = normalizeServerUrl();

    if (playlistCode.trim().isNotEmpty && base.isNotEmpty) {
      return '$base/api/player/playlists/by-code/${Uri.encodeComponent(playlistCode.trim())}';
    }

    return playlistUrl.trim();
  }

  KioskSettings copyWith({
    String? playlistUrl,
    String? playlistCode,
    String? deviceId,
    String? deviceName,
    String? deviceSerial,
    String? enrollCode,
    int? refreshIntervalSeconds,
    bool? autoFullscreen,
    bool? alwaysOnTop,
    bool? remoteControlEnabled,
    int? remoteControlPort,
    String? remoteControlToken,
    bool? mdmEnabled,
    String? mdmServerUrl,
    String? mdmDeviceToken,
    int? mdmRuntimeIntervalSeconds,
  }) {
    return KioskSettings(
      playlistUrl: playlistUrl ?? this.playlistUrl,
      playlistCode: playlistCode ?? this.playlistCode,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      enrollCode: enrollCode ?? this.enrollCode,
      refreshIntervalSeconds: refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      autoFullscreen: autoFullscreen ?? this.autoFullscreen,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      remoteControlEnabled: remoteControlEnabled ?? this.remoteControlEnabled,
      remoteControlPort: remoteControlPort ?? this.remoteControlPort,
      remoteControlToken: remoteControlToken ?? this.remoteControlToken,
      mdmEnabled: mdmEnabled ?? this.mdmEnabled,
      mdmServerUrl: mdmServerUrl ?? this.mdmServerUrl,
      mdmDeviceToken: mdmDeviceToken ?? this.mdmDeviceToken,
      mdmRuntimeIntervalSeconds:
      mdmRuntimeIntervalSeconds ?? this.mdmRuntimeIntervalSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'playlistUrl': playlistUrl,
    'playlistCode': playlistCode,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'deviceSerial': deviceSerial,
    'enrollCode': enrollCode,
    'refreshIntervalSeconds': refreshIntervalSeconds,
    'autoFullscreen': autoFullscreen,
    'alwaysOnTop': alwaysOnTop,
    'remoteControlEnabled': remoteControlEnabled,
    'remoteControlPort': remoteControlPort,
    'remoteControlToken': remoteControlToken,
    'mdmEnabled': mdmEnabled,
    'mdmServerUrl': mdmServerUrl,
    'mdmDeviceToken': mdmDeviceToken,
    'mdmRuntimeIntervalSeconds': mdmRuntimeIntervalSeconds,
  };

  factory KioskSettings.fromJson(Map<String, dynamic> json) {
    final initial = KioskSettings.initial();
    return KioskSettings(
      playlistUrl: json['playlistUrl']?.toString() ?? initial.playlistUrl,
      playlistCode: json['playlistCode']?.toString() ?? initial.playlistCode,
      deviceId: json['deviceId']?.toString() ?? initial.deviceId,
      deviceName: json['deviceName']?.toString() ?? initial.deviceName,
      deviceSerial: json['deviceSerial']?.toString() ?? initial.deviceSerial,
      enrollCode: json['enrollCode']?.toString() ?? initial.enrollCode,
      refreshIntervalSeconds:
      int.tryParse(json['refreshIntervalSeconds']?.toString() ?? '') ??
          initial.refreshIntervalSeconds,
      autoFullscreen: json['autoFullscreen'] != false,
      alwaysOnTop: json['alwaysOnTop'] != false,
      remoteControlEnabled: json['remoteControlEnabled'] != false,
      remoteControlPort:
      int.tryParse(json['remoteControlPort']?.toString() ?? '') ??
          initial.remoteControlPort,
      remoteControlToken:
      json['remoteControlToken']?.toString() ?? initial.remoteControlToken,
      mdmEnabled: json['mdmEnabled'] == true,
      mdmServerUrl: json['mdmServerUrl']?.toString() ?? initial.mdmServerUrl,
      mdmDeviceToken:
      json['mdmDeviceToken']?.toString() ?? initial.mdmDeviceToken,
      mdmRuntimeIntervalSeconds:
      int.tryParse(json['mdmRuntimeIntervalSeconds']?.toString() ?? '') ??
          initial.mdmRuntimeIntervalSeconds,
    );
  }
}