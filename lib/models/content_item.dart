enum ContentType {
  image,
  video,
  audio,
  pdf,
  web,
  slide,
  unknown,
}

String contentTypeLabel(ContentType type) {
  switch (type) {
    case ContentType.image:
      return 'Hình ảnh';
    case ContentType.video:
      return 'Video';
    case ContentType.audio:
      return 'Âm thanh';
    case ContentType.pdf:
      return 'PDF';
    case ContentType.web:
      return 'Trang web';
    case ContentType.slide:
      return 'Trình chiếu';
    case ContentType.unknown:
      return 'Không xác định';
  }
}

ContentType contentTypeFromString(String? value) {
  final v = (value ?? '').trim().toLowerCase();

  if (v.contains('image') ||
      v == 'img' ||
      v == 'photo' ||
      v == 'picture') {
    return ContentType.image;
  }
  if (v.contains('video') || v == 'movie' || v == 'mp4') {
    return ContentType.video;
  }
  if (v.contains('audio') ||
      v == 'sound' ||
      v == 'music' ||
      v == 'mp3') {
    return ContentType.audio;
  }
  if (v.contains('pdf')) {
    return ContentType.pdf;
  }
  if (v.contains('slide') || v == 'ppt' || v == 'pptx') {
    return ContentType.slide;
  }
  if (v == 'website' || v == 'browser' || v == 'url' || v.contains('web')) {
    return ContentType.web;
  }

  return ContentType.unknown;
}

class ContentItem {
  final String id;
  final String code;
  final ContentType type;
  final String title;
  final String? subtitle;
  final String url;
  final int durationSeconds;
  final bool autoNext;
  final int? sortOrder;
  final int? position;
  final String? createdAt;
  final Map<String, dynamic> raw;

  const ContentItem({
    required this.id,
    required this.code,
    required this.type,
    required this.title,
    required this.url,
    this.subtitle,
    this.durationSeconds = 0,
    this.autoNext = true,
    this.sortOrder,
    this.position,
    this.createdAt,
    this.raw = const <String, dynamic>{},
  });

  bool get durationConfigured => durationSeconds > 0;

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    final source = Map<String, dynamic>.from(json);

    final url = _pickString(source, const [
      'source_url',
      'url',
      'content_url',
      'media_url',
      'current_url',
    ]) ??
        '';

    final rawType = _pickString(source, const [
      'item_type',
      'asset_type',
      'type',
      'content_type',
      'media_type',
    ]) ??
        _detectTypeFromUrl(url) ??
        'unknown';

    return ContentItem(
      id: _pickString(source, const ['id']) ?? '',
      code: _pickString(source, const [
        'code',
        'content_code',
        'asset_code',
        'slug',
      ]) ??
          '',
      type: contentTypeFromString(rawType),
      title: _pickString(source, const [
        'title',
        'name',
        'display_name',
        'label',
      ]) ??
          'Nội dung',
      subtitle: _pickString(source, const [
        'subtitle',
        'description',
      ]),
      url: url,
      durationSeconds: _pickInt(source, const [
        'duration_sec',
        'duration',
        'durationSeconds',
      ]) ??
          0,
      autoNext: _pickBool(source, const [
        'auto_next',
        'autoNext',
      ]) ??
          true,
      sortOrder: _pickInt(source, const [
        'sort_order',
        'sortOrder',
      ]),
      position: _pickInt(source, const [
        'position',
        'index',
        'order',
      ]),
      createdAt: _pickString(source, const [
        'created_at',
        'createdAt',
      ]),
      raw: source,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...raw,
      'id': id,
      'code': code,
      'title': title,
      'subtitle': subtitle,
      'url': url,
      'content_type': type.name,
      'duration_sec': durationSeconds,
      'auto_next': autoNext,
      'sort_order': sortOrder,
      'position': position,
      'created_at': createdAt,
    };
  }

  ContentItem copyWith({
    String? id,
    String? code,
    ContentType? type,
    String? title,
    String? subtitle,
    String? url,
    int? durationSeconds,
    bool? autoNext,
    int? sortOrder,
    int? position,
    String? createdAt,
    Map<String, dynamic>? raw,
  }) {
    return ContentItem(
      id: id ?? this.id,
      code: code ?? this.code,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      url: url ?? this.url,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      autoNext: autoNext ?? this.autoNext,
      sortOrder: sortOrder ?? this.sortOrder,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      raw: raw ?? this.raw,
    );
  }

  static List<ContentItem> sortList(List<ContentItem> items) {
    final sorted = List<ContentItem>.from(items);
    sorted.sort(compare);
    return sorted;
  }

  static int compare(ContentItem a, ContentItem b) {
    final aSort = a.sortOrder ?? 0;
    final bSort = b.sortOrder ?? 0;
    if (aSort != bSort) return aSort.compareTo(bSort);

    final aPos = a.position ?? 0;
    final bPos = b.position ?? 0;
    if (aPos != bPos) return aPos.compareTo(bPos);

    final aCreated = (a.createdAt ?? '').trim();
    final bCreated = (b.createdAt ?? '').trim();
    final createdCompare = aCreated.compareTo(bCreated);
    if (createdCompare != 0) return createdCompare;

    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static String? _pickString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _pickInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static bool? _pickBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;

      if (value is bool) return value;

      final text = value.toString().trim().toLowerCase();
      if (text == 'true' || text == '1' || text == 'yes' || text == 'on') {
        return true;
      }
      if (text == 'false' || text == '0' || text == 'no' || text == 'off') {
        return false;
      }
    }
    return null;
  }

  static String? _detectTypeFromUrl(String? url) {
    final raw = (url ?? '').trim().toLowerCase();
    if (raw.isEmpty) return null;

    final clean = raw.split('?').first.split('#').first;

    if (clean.endsWith('.pdf')) return 'pdf';
    if (clean.endsWith('.ppt') || clean.endsWith('.pptx')) return 'slide';

    if (clean.endsWith('.mp3') ||
        clean.endsWith('.wav') ||
        clean.endsWith('.aac') ||
        clean.endsWith('.ogg') ||
        clean.endsWith('.m4a')) {
      return 'audio';
    }

    if (clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.webm')) {
      return 'video';
    }

    if (clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.bmp') ||
        clean.endsWith('.webp')) {
      return 'image';
    }

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return 'web';
    }

    return null;
  }
}