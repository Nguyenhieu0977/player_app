import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../models/content_item.dart';
import '../../services/playback_bridge.dart';

class WebRenderer extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onReady;

  const WebRenderer({
    super.key,
    required this.item,
    required this.onReady,
  });

  @override
  State<WebRenderer> createState() => _WebRendererState();
}

class _WebRendererState extends State<WebRenderer> {
  InAppWebViewController? _controller;
  StreamSubscription<PlaybackCommand>? _commandSub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _commandSub = PlaybackBridge.instance.stream.listen(_handleCommand);
  }

  @override
  void didUpdateWidget(covariant WebRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.url != widget.item.url && widget.item.url.isNotEmpty) {
      _isLoading = true;
      _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(widget.item.url)),
      );
    }
  }

  @override
  void dispose() {
    _commandSub?.cancel();
    super.dispose();
  }

  Future<void> _handleCommand(PlaybackCommand command) async {
    switch (command.type) {
      case 'reload':
        _isLoading = true;
        if (mounted) setState(() {});
        await _controller?.reload();
        break;
      case 'open_web':
        final url = command.payload['url']?.toString().trim() ?? '';
        if (url.isNotEmpty) {
          _isLoading = true;
          if (mounted) setState(() {});
          await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.url.isEmpty) {
      return const Center(
        child: Text(
          'URL không hợp lệ',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.item.url)),
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onLoadStart: (controller, url) {
            if (!_isLoading) {
              setState(() => _isLoading = true);
            }
          },
          onLoadStop: (controller, url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            widget.onReady();
          },
          onLoadError: (controller, url, code, message) {
            debugPrint('Web lỗi: $message');
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}