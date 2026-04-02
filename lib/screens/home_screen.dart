import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme/app_colors.dart';
import '../models/kiosk_settings.dart';
import '../state/kiosk_controller.dart';
import '../widgets/top_status_bar.dart';
import 'player_shell.dart';
import 'settings_screen.dart';
import '../models/content_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _openingShell = false;
  bool _shellOpened = false;

  void _maybeOpenShell(KioskController controller) {
    final shouldOpen = !_openingShell &&
        !_shellOpened &&
        !controller.bootstrapping &&
        controller.shellRequested;

    if (!shouldOpen) return;

    _openingShell = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _openingShell = false;
        return;
      }

      _shellOpened = true;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PlayerShell(),
        ),
      );

      _shellOpened = false;
      _openingShell = false;

      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KioskController>(
      builder: (context, controller, _) {
        _maybeOpenShell(controller);

        if (controller.bootstrapping) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.background, AppColors.backgroundSoft],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TopStatusBar(
                      title: 'Kiosk Player',
                      subtitle: 'Trình phát nội dung cho PC / Raspberry Pi',
                      right: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings_rounded),
                            label: const Text('Cấu hình'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () {
                              controller.requestShellOpen();
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Chạy kiosk'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _SummaryPanel(settings: controller.settings),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 7,
                            child: _PlaylistPanel(
                              items: controller.playlist,
                              onTap: controller.jumpTo,
                              currentIndex: controller.currentIndex,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final KioskSettings settings;

  const _SummaryPanel({required this.settings});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KioskController>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Thiết bị hiện tại',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _InfoRow(label: 'Mã thiết bị', value: settings.deviceId),
                    _InfoRow(label: 'Tên hiển thị', value: settings.deviceName),
                    _InfoRow(
                      label: 'Nguồn playlist',
                      value: controller.resolvedPlaylistCode ?? settings.playlistUrl,
                    ),
                    _InfoRow(
                      label: 'Resolve từ',
                      value: controller.resolvedFrom ??
                          (settings.mdmEnabled
                              ? 'MDM / resolved playlist'
                              : 'Thủ công / fallback'),
                    ),
                    _InfoRow(
                      label: 'Làm mới',
                      value: '${settings.refreshIntervalSeconds} giây/lần',
                    ),
                    _InfoRow(
                      label: 'Toàn màn hình',
                      value: settings.autoFullscreen ? 'Bật' : 'Tắt',
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Số nội dung',
                            value: '${controller.playlist.length}',
                            icon: Icons.view_carousel_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Đang chạy',
                            value: controller.currentItem?.type.name.toUpperCase() ?? '--',
                            icon: Icons.play_circle_fill_rounded,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (controller.error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.danger.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          'Lỗi tải playlist: ${controller.error}',
                          style: const TextStyle(
                            color: Color(0xFFFFD5D5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: controller.refreshPlaylist,
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('Tải lại playlist'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlaylistPanel extends StatelessWidget {
  final List items;
  final ValueChanged<int> onTap;
  final int currentIndex;

  const _PlaylistPanel({
    required this.items,
    required this.onTap,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh sách phát',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhấn vào từng mục để kiểm tra nhanh trước khi chạy toàn màn hình',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) {
                final item = items[index];
                final isActive = index == currentIndex;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onTap(index),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.cardAlt : const Color(0xFF0E1C31),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isActive ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _iconFor(contentTypeLabel(item.type)),
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title?.toString().trim().isNotEmpty == true
                                    ? item.title.toString()
                                    : 'Nội dung ${index + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${contentTypeLabel(item.type)} • ${item.url ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: items.length,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.movie_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'web':
        return Icons.language_rounded;
      default:
        return Icons.slideshow_rounded;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value ?? '--').trim().isEmpty ? '--' : value!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}