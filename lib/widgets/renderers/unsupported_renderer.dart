import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../models/content_item.dart';

class UnsupportedRenderer extends StatelessWidget {
  final ContentItem item;

  const UnsupportedRenderer({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.warning, size: 56),
            const SizedBox(height: 16),
            Text(
              'Chưa hỗ trợ loại nội dung: ${contentTypeLabel(item.type)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.url,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
