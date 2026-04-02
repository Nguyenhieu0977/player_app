import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/kiosk_settings.dart';

class SettingsService {
  static const _key = 'kiosk_settings_v2';

  Future<KioskSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return KioskSettings.initial();
    }

    try {
      return KioskSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return KioskSettings.initial();
    }
  }

  Future<void> save(KioskSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}