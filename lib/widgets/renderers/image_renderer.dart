import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../models/content_item.dart';

class ImageRenderer extends StatelessWidget {
  final ContentItem item;
  final VoidCallback onReady;

  const ImageRenderer({
    super.key,
    required this.item,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          item.url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, __, ___) => _error(),
        ),
        Positioned(
          left: 24,
          bottom: 24,
          child: _titleBox(),
        ),
      ],
    );
  }

  Widget _titleBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          if ((item.subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _error() {
    return const Center(
      child: Text(
        'Không tải được hình ảnh',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
