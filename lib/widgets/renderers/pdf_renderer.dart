import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../models/content_item.dart';
import '../../services/file_cache_service.dart';
import '../../services/playback_bridge.dart';

class PdfRenderer extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onReady;

  const PdfRenderer({
    super.key,
    required this.item,
    required this.onReady,
  });

  @override
  State<PdfRenderer> createState() => _PdfRendererState();
}

class _PdfRendererState extends State<PdfRenderer> {
  final _cacheService = FileCacheService();
  Future<File>? _futureFile;
  StreamSubscription<PlaybackCommand>? _commandSub;

  int _requestedPage = 1;
  bool _readyReported = false;

  @override
  void initState() {
    super.initState();
    _futureFile = _cacheService.download(widget.item.url);
    _commandSub = PlaybackBridge.instance.stream.listen(_handleCommand);
  }

  @override
  void didUpdateWidget(covariant PdfRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.url != widget.item.url) {
      _requestedPage = 1;
      _readyReported = false;
      _futureFile = _cacheService.download(widget.item.url);
    }
  }

  void _handleCommand(PlaybackCommand command) {
    if (!mounted) return;

    int? targetPage;

    if (command.type == 'page') {
      targetPage = int.tryParse(command.payload['page']?.toString() ?? '');
    } else if (command.type == 'next_page') {
      targetPage = _requestedPage + 1;
    } else if (command.type == 'prev_page') {
      targetPage = _requestedPage - 1;
    } else {
      return;
    }

    if (targetPage == null || targetPage <= 0 || targetPage == _requestedPage) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _requestedPage = targetPage!;
      });
    });
  }

  @override
  void dispose() {
    _commandSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _futureFile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'Không tải được PDF',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        if (!_readyReported) {
          _readyReported = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onReady();
          });
        }

        return PdfViewer.file(
          snapshot.data!.path,
          key: ValueKey('pdf_${snapshot.data!.path}_$_requestedPage'),
          initialPageNumber: _requestedPage,
        );
      },
    );
  }
}