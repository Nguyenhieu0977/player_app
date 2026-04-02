import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class FileCacheService {
  final Dio _dio = Dio();

  Future<File> download(String url, {String? fileName}) async {
    final dir = await getTemporaryDirectory();
    final sanitized = fileName ?? url.split('/').last.split('?').first;
    final file = File('${dir.path}/$sanitized');
    if (await file.exists() && await file.length() > 0) {
      return file;
    }
    await _dio.download(url, file.path);
    return file;
  }
}
