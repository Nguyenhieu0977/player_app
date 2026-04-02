import 'content_item.dart';

class PlaylistResponse {
  final String? name;
  final String? code;
  final String? resolvedFrom;
  final String? assignmentId;
  final Map<String, dynamic> scopeContext;
  final List<ContentItem> items;

  const PlaylistResponse({
    this.name,
    this.code,
    this.resolvedFrom,
    this.assignmentId,
    this.scopeContext = const <String, dynamic>{},
    required this.items,
  });

  factory PlaylistResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> root = Map<String, dynamic>.from(json);

    final Map<String, dynamic> playlistMap =
    root['playlist'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(root['playlist'] as Map<String, dynamic>)
        : (root['playlist'] is Map
        ? Map<String, dynamic>.from(root['playlist'] as Map)
        : root);

    final List<dynamic> rawItems = _extractItems(root, playlistMap);

    final scopeContext = root['scope_context'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(root['scope_context'] as Map<String, dynamic>)
        : (root['scope_context'] is Map
        ? Map<String, dynamic>.from(root['scope_context'] as Map)
        : const <String, dynamic>{});

    final items = rawItems
        .whereType<Map>()
        .map((e) => ContentItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.url.trim().isNotEmpty)
        .toList();

    return PlaylistResponse(
      name: playlistMap['title']?.toString() ??
          playlistMap['name']?.toString() ??
          root['name']?.toString(),
      code: root['playlist_code']?.toString() ??
          playlistMap['code']?.toString() ??
          root['code']?.toString(),
      resolvedFrom: root['resolved_from']?.toString(),
      assignmentId: root['assignment_id']?.toString(),
      scopeContext: scopeContext,
      items: ContentItem.sortList(items),
    );
  }

  static List<dynamic> _extractItems(
      Map<String, dynamic> root,
      Map<String, dynamic> playlistMap,
      ) {
    final candidates = <dynamic>[
      playlistMap['items'],
      playlistMap['playlist_items'],
      playlistMap['playlist'],
      root['items'],
      root['playlist_items'],
      root['data'] is Map ? (root['data'] as Map)['items'] : null,
      root['data'] is Map ? (root['data'] as Map)['playlist_items'] : null,
    ];

    for (final candidate in candidates) {
      if (candidate is List) return candidate;
    }

    return const <dynamic>[];
  }
}