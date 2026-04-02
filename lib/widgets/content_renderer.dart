import 'package:flutter/material.dart';

import '../models/content_item.dart';
import 'renderers/audio_renderer.dart';
import 'renderers/image_renderer.dart';
import 'renderers/pdf_renderer.dart';
import 'renderers/unsupported_renderer.dart';
import 'renderers/video_renderer.dart';
import 'renderers/web_renderer.dart';

class ContentRenderer extends StatelessWidget {
  final ContentItem item;
  final VoidCallback onCompleted;
  final VoidCallback onReady;

  const ContentRenderer({
    super.key,
    required this.item,
    required this.onCompleted,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case ContentType.image:
        return ImageRenderer(item: item, onReady: onReady);
      case ContentType.video:
        return VideoRenderer(item: item, onCompleted: onCompleted);
      case ContentType.audio:
        return AudioRenderer(item: item, onCompleted: onCompleted);
      case ContentType.pdf:
        return PdfRenderer(item: item, onReady: onReady);
      case ContentType.web:
      case ContentType.slide:
        if (item.url.isEmpty) {
          return const Center(
            child: Text(
              'Không có URL',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return WebRenderer(
          item: item,
          onReady: onReady,
        );
      case ContentType.unknown:
        return UnsupportedRenderer(item: item);
    }
  }
}
