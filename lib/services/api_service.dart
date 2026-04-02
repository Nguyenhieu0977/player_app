import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/content_item.dart';
import '../models/playlist_response.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );

  Future<PlaylistResponse> fetchPlaylist(
      String url, {
        Map<String, String>? headers,
      }) async {
    final response = await _dio.get(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: headers,
      ),
    );

    final raw = response.data;
    final dynamic data = raw is String ? jsonDecode(raw) : raw;

    if (data is Map<String, dynamic>) {
      return PlaylistResponse.fromJson(data);
    }

    if (data is List) {
      final items = data
          .whereType<Map>()
          .map((e) => ContentItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.url.trim().isNotEmpty)
          .toList();

      return PlaylistResponse(
        name: 'Danh sách phát',
        code: null,
        resolvedFrom: null,
        assignmentId: null,
        scopeContext: const <String, dynamic>{},
        items: ContentItem.sortList(items),
      );
    }

    throw Exception('Dữ liệu playlist không hợp lệ');
  }

  Future<PlaylistResponse> fetchResolvedPlaylist({
    required String serverUrl,
    required String deviceToken,
  }) {
    final base = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    return fetchPlaylist(
      '$base/api/player/me/playlist',
      headers: {
        'Authorization': 'Bearer $deviceToken',
      },
    );
  }

  List<ContentItem> demoPlaylist() {
    return ContentItem.sortList(
      const [
        ContentItem(
          id: 'img-1',
          code: 'img-1',
          type: ContentType.image,
          title: 'Banner chào mừng',
          subtitle: 'Ảnh demo từ Internet',
          url:
          'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=1600&q=80',
          durationSeconds: 12,
          autoNext: true,
          sortOrder: 1,
          position: 1,
        ),
        ContentItem(
          id: 'video-1',
          code: 'video-1',
          type: ContentType.video,
          title: 'Video demo Big Buck Bunny',
          subtitle: 'Phát video trực tuyến',
          url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          durationSeconds: 30,
          autoNext: true,
          sortOrder: 2,
          position: 2,
        ),
      ],
    );
  }
}