import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme/app_colors.dart';
import '../services/window_service.dart';
import '../state/kiosk_controller.dart';
import '../widgets/content_renderer.dart';

class PlayerShell extends StatefulWidget {
  const PlayerShell({super.key});

  @override
  State<PlayerShell> createState() => _PlayerShellState();
}

class _PlayerShellState extends State<PlayerShell> {
  static const Duration _overlayAutoHideDelay = Duration(seconds: 4);

  final _windowService = WindowService();

  bool _overlayVisible = true;
  bool _closing = false;

  Timer? _overlayHideTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<KioskController>();
      await _windowService.applyKioskMode(
        fullscreen: controller.settings.autoFullscreen,
        alwaysOnTop: controller.settings.alwaysOnTop,
      );
      await controller.warmupCurrentPdfIfNeeded();
      _showOverlayTemporarily();
    });
  }

  @override
  void dispose() {
    _overlayHideTimer?.cancel();
    super.dispose();
  }

  void _maybeClose(KioskController controller) {
    final shouldClose =
        !_closing && !controller.bootstrapping && !controller.shellRequested;

    if (!shouldClose) return;

    _closing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _overlayHideTimer?.cancel();
      await _windowService.exitKioskMode();
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  void _showOverlayTemporarily() {
    if (!mounted) return;

    _overlayHideTimer?.cancel();

    if (!_overlayVisible) {
      setState(() {
        _overlayVisible = true;
      });
    } else {
      setState(() {});
    }

    _overlayHideTimer = Timer(_overlayAutoHideDelay, () {
      if (!mounted) return;
      setState(() {
        _overlayVisible = false;
      });
    });
  }

  void _hideOverlay() {
    _overlayHideTimer?.cancel();
    if (!mounted) return;
    if (_overlayVisible) {
      setState(() {
        _overlayVisible = false;
      });
    }
  }

  String _footerTitle(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return 'CHƯA CÓ NỘI DUNG';
    return value.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KioskController>(
      builder: (context, controller, _) {
        _maybeClose(controller);

        final item = controller.currentItem;

        return Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (_) => _showOverlayTemporarily(),
            onEnter: (_) => _showOverlayTemporarily(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showOverlayTemporarily,
              onPanDown: (_) => _showOverlayTemporarily,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: item == null
                        ? const Center(
                      child: Text(
                        'Chưa có nội dung để phát',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                        : ContentRenderer(
                      key: ValueKey('${item.id}-${controller.currentIndex}'),
                      item: item,
                      onCompleted: controller.onRendererCompleted,
                      onReady: () {
                        controller.onRendererReady();
                        _showOverlayTemporarily();
                      },
                    ),
                  ),

                  Positioned(
                    top: 24,
                    left: 24,
                    right: 24,
                    child: IgnorePointer(
                      ignoring: !_overlayVisible,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: _overlayVisible ? 1 : 0,
                        child: _TopOverlay(
                          title: controller.settings.deviceName,
                          itemTitle: item?.title ?? 'Không có nội dung',
                          itemType: item?.type.name.toUpperCase() ?? '--',
                          onBack: () {
                            _showOverlayTemporarily();
                            controller.requestHome();
                          },
                          onPrev: () {
                            _showOverlayTemporarily();
                            controller.previous();
                          },
                          onNext: () {
                            _showOverlayTemporarily();
                            controller.next();
                          },
                          onRefresh: () {
                            _showOverlayTemporarily();
                            controller.refreshPlaylist();
                          },
                          onHide: _hideOverlay,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 24,
                    top: 110,
                    child: IgnorePointer(
                      ignoring: !_overlayVisible,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: _overlayVisible ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card.withOpacity(0.78),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '${controller.currentIndex + 1} / ${controller.playlist.length}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 18,
                    child: IgnorePointer(
                      ignoring: true,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 280),
                        opacity: 1,
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 900),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Text(
                              _footerTitle(item?.title),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.62),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopOverlay extends StatelessWidget {
  final String title;
  final String itemTitle;
  final String itemType;
  final VoidCallback onBack;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onRefresh;
  final VoidCallback onHide;

  const _TopOverlay({
    required this.title,
    required this.itemTitle,
    required this.itemType,
    required this.onBack,
    required this.onPrev,
    required this.onNext,
    required this.onRefresh,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.85)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _CircleIconButton(
            tooltip: 'Về trang chính',
            icon: Icons.home_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$itemType • $itemTitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.92),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ActionChip(
            icon: Icons.skip_previous_rounded,
            label: 'Lùi',
            onTap: onPrev,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.sync_rounded,
            label: 'Tải lại',
            onTap: onRefresh,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.skip_next_rounded,
            label: 'Tiếp',
            primary: true,
            onTap: onNext,
          ),
          const SizedBox(width: 8),
          _CircleIconButton(
            tooltip: 'Ẩn điều khiển',
            icon: Icons.visibility_off_rounded,
            onTap: onHide,
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = primary
        ? AppColors.primary.withOpacity(0.92)
        : Colors.white.withOpacity(0.06);

    final Color border = primary
        ? AppColors.primary.withOpacity(0.95)
        : Colors.white.withOpacity(0.08);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}