import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme/app_colors.dart';
import '../models/kiosk_settings.dart';
import '../state/kiosk_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _urlCtrl;
  late final TextEditingController _playlistCodeCtrl;
  late final TextEditingController _deviceIdCtrl;
  late final TextEditingController _deviceNameCtrl;
  late final TextEditingController _deviceSerialCtrl;
  late final TextEditingController _enrollCodeCtrl;
  late final TextEditingController _refreshCtrl;

  late bool _fullscreen;
  late bool _alwaysOnTop;

  late bool _remoteEnabled;
  late final TextEditingController _remotePortCtrl;
  late final TextEditingController _remoteTokenCtrl;

  late bool _mdmEnabled;
  late final TextEditingController _mdmServerUrlCtrl;
  late final TextEditingController _mdmRuntimeIntervalCtrl;
  late final TextEditingController _mdmDeviceTokenCtrl;

  @override
  void initState() {
    super.initState();
    final settings = context.read<KioskController>().settings;

    _urlCtrl = TextEditingController(text: settings.playlistUrl);
    _playlistCodeCtrl = TextEditingController(text: settings.playlistCode);
    _deviceIdCtrl = TextEditingController(text: settings.deviceId);
    _deviceNameCtrl = TextEditingController(text: settings.deviceName);
    _deviceSerialCtrl = TextEditingController(text: settings.deviceSerial);
    _enrollCodeCtrl = TextEditingController(text: settings.enrollCode);
    _refreshCtrl =
        TextEditingController(text: settings.refreshIntervalSeconds.toString());

    _remotePortCtrl =
        TextEditingController(text: settings.remoteControlPort.toString());
    _remoteTokenCtrl = TextEditingController(text: settings.remoteControlToken);

    _mdmServerUrlCtrl = TextEditingController(text: settings.mdmServerUrl);
    _mdmRuntimeIntervalCtrl = TextEditingController(
      text: settings.mdmRuntimeIntervalSeconds.toString(),
    );
    _mdmDeviceTokenCtrl = TextEditingController(text: settings.mdmDeviceToken);

    _fullscreen = settings.autoFullscreen;
    _alwaysOnTop = settings.alwaysOnTop;
    _remoteEnabled = settings.remoteControlEnabled;
    _mdmEnabled = settings.mdmEnabled;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _playlistCodeCtrl.dispose();
    _deviceIdCtrl.dispose();
    _deviceNameCtrl.dispose();
    _deviceSerialCtrl.dispose();
    _enrollCodeCtrl.dispose();
    _refreshCtrl.dispose();
    _remotePortCtrl.dispose();
    _remoteTokenCtrl.dispose();
    _mdmServerUrlCtrl.dispose();
    _mdmRuntimeIntervalCtrl.dispose();
    _mdmDeviceTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KioskController>();
    _deviceIdCtrl.text = controller.settings.deviceId;
    _mdmDeviceTokenCtrl.text = controller.settings.mdmDeviceToken;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Cấu hình kiosk'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thiết bị và nguồn dữ liệu',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        controller: _playlistCodeCtrl,
                        label: 'Mã kịch bản (ưu tiên)',
                        hint: 'meeting_room_a_main',
                        validator: null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _urlCtrl,
                        label: 'URL playlist fallback',
                        hint: 'https://server.local/kiosk/playlist.json',
                        validator: null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              controller: _deviceNameCtrl,
                              label: 'Tên hiển thị',
                              hint: 'TV Phòng họp A',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildField(
                              controller: _deviceSerialCtrl,
                              label: 'Serial thiết bị',
                              hint: 'WIN-PC-01',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _refreshCtrl,
                        label: 'Chu kỳ tải playlist (giây)',
                        hint: '60',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _fullscreen,
                        onChanged: (v) => setState(() => _fullscreen = v),
                        title: const Text('Tự vào toàn màn hình khi chạy'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _alwaysOnTop,
                        onChanged: (v) => setState(() => _alwaysOnTop = v),
                        title: const Text('Luôn ở trên cùng'),
                      ),
                      const Divider(height: 28),
                      const Text(
                        'Điều khiển từ xa nội bộ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _remoteEnabled,
                        onChanged: (v) => setState(() => _remoteEnabled = v),
                        title: const Text('Bật API điều khiển từ xa local'),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              controller: _remotePortCtrl,
                              label: 'Port điều khiển',
                              hint: '9527',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildField(
                              controller: _remoteTokenCtrl,
                              label: 'Token điều khiển',
                              hint: 'k7-demo-token',
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      const Text(
                        'Kết nối MDM / FastAPI',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _mdmEnabled,
                        onChanged: (v) => setState(() => _mdmEnabled = v),
                        title: const Text('Bật kết nối WebSocket tới MDM'),
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildField(
                              controller: _mdmServerUrlCtrl,
                              label: 'MDM Server URL',
                              hint: 'http://192.168.1.216',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildField(
                              controller: _mdmRuntimeIntervalCtrl,
                              label: 'Chu kỳ gửi runtime (giây)',
                              hint: '20',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _enrollCodeCtrl,
                        label: 'Mã enroll',
                        hint: 'WINDOWS-XXXXXX',
                        validator: null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildReadOnlyField(
                              controller: _deviceIdCtrl,
                              label: 'Device ID',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildReadOnlyField(
                              controller: _mdmDeviceTokenCtrl,
                              label: 'Device token',
                              obscureText: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: controller.enrolling
                                  ? null
                                  : _registerDevice,
                              icon: controller.enrolling
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Icon(Icons.link_rounded),
                              label: Text(
                                controller.enrolling
                                    ? 'Đang đăng ký...'
                                    : 'Đăng ký thiết bị',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: controller.enrolling
                                  ? null
                                  : _clearEnrollment,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Xóa thông tin đăng ký'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1A2D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Trạng thái MDM hiện tại: ${controller.mdmConnected ? "Đang kết nối" : "Chưa kết nối"}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Đóng'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Lưu cấu hình'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ??
              (v) {
            if ((v ?? '').trim().isEmpty) return 'Không được để trống';
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF0D1A2D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF0D1A2D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _registerDevice() async {
    if (_mdmServerUrlCtrl.text.trim().isEmpty) {
      _showMessage('Bạn chưa nhập MDM Server URL');
      return;
    }
    if (_enrollCodeCtrl.text.trim().isEmpty) {
      _showMessage('Bạn chưa nhập mã enroll');
      return;
    }

    final controller = context.read<KioskController>();

    try {
      await controller.enrollDevice(
        serverUrl: _mdmServerUrlCtrl.text.trim(),
        code: _enrollCodeCtrl.text.trim(),
        displayName: _deviceNameCtrl.text.trim(),
        serial: _deviceSerialCtrl.text.trim(),
      );

      if (!mounted) return;

      _deviceIdCtrl.text = controller.settings.deviceId;
      _mdmDeviceTokenCtrl.text = controller.settings.mdmDeviceToken;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thiết bị thành công')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    }
  }

  Future<void> _clearEnrollment() async {
    final controller = context.read<KioskController>();
    await controller.clearDeviceEnrollment();

    if (!mounted) return;
    _deviceIdCtrl.clear();
    _mdmDeviceTokenCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xóa thông tin đăng ký thiết bị')),
    );
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<KioskController>();
    final settings = KioskSettings(
      playlistUrl: _urlCtrl.text.trim(),
      playlistCode: _playlistCodeCtrl.text.trim(),
      deviceId: _deviceIdCtrl.text.trim(),
      deviceName: _deviceNameCtrl.text.trim(),
      deviceSerial: _deviceSerialCtrl.text.trim(),
      enrollCode: _enrollCodeCtrl.text.trim(),
      refreshIntervalSeconds: int.tryParse(_refreshCtrl.text.trim()) ?? 60,
      autoFullscreen: _fullscreen,
      alwaysOnTop: _alwaysOnTop,
      remoteControlEnabled: _remoteEnabled,
      remoteControlPort: int.tryParse(_remotePortCtrl.text.trim()) ?? 9527,
      remoteControlToken: _remoteTokenCtrl.text.trim(),
      mdmEnabled: _mdmEnabled,
      mdmServerUrl: _mdmServerUrlCtrl.text.trim(),
      mdmDeviceToken: _mdmDeviceTokenCtrl.text.trim(),
      mdmRuntimeIntervalSeconds:
      int.tryParse(_mdmRuntimeIntervalCtrl.text.trim()) ?? 20,
    );

    await controller.saveSettings(settings);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu cấu hình')),
    );
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}