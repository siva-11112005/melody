class Track {
  final String id;
  final String title;
  final String artist;
  final String? artwork;
  final String? url;
  final int durationMs;
  final List<dynamic> downloadUrl;
  final String? localUri;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.artwork,
    this.url,
    this.durationMs = 0,
    this.downloadUrl = const [],
    this.localUri,
  });

  factory Track.fromApi(Map<String, dynamic> json) {
    final image = (json['image'] as List?) ?? const [];
    final dl = (json['downloadUrl'] as List?) ?? const [];
    final rawDuration = (json['duration'] is int)
        ? json['duration'] as int
        : int.tryParse('${json['duration'] ?? 0}') ?? 0;
    final durationMs = rawDuration < 1000 ? rawDuration * 1000 : rawDuration;

    String? bestImage = json['artwork'] as String?;
    if (image.isNotEmpty) {
      final last = image.last;
      if (last is Map && last['url'] is String) {
        bestImage = last['url'] as String;
      }
    }

    String? bestUrl = json['url'] as String?;
    if (dl.isNotEmpty) {
      final last = dl.last;
      if (last is Map && last['url'] is String) {
        bestUrl = last['url'] as String;
      }
    }

    final artists = json['artists'] as Map<String, dynamic>?;
    final primary = artists?['primary'] as List?;
    String resolvedArtist = (json['artist'] ?? '').toString();
    if (primary != null && primary.isNotEmpty) {
      final names = primary
          .whereType<Map>()
          .map((e) => (e['name'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        resolvedArtist = names.join(', ');
      }
    }

    return Track(
      id: (json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      title: ((json['name'] ?? json['title']) ?? 'Unknown').toString(),
      artist: resolvedArtist.isEmpty ? 'Unknown' : resolvedArtist,
      artwork: bestImage,
      url: bestUrl,
      durationMs: durationMs,
      downloadUrl: dl,
      localUri: json['localUri'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artwork': artwork,
        'url': url,
        'duration': durationMs,
        'downloadUrl': downloadUrl,
        'localUri': localUri,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        artist: (json['artist'] ?? '').toString(),
        artwork: json['artwork'] as String?,
        url: json['url'] as String?,
        durationMs: (json['duration'] is int)
            ? json['duration'] as int
            : int.tryParse('${json['duration'] ?? 0}') ?? 0,
        downloadUrl: (json['downloadUrl'] as List?) ?? const [],
        localUri: json['localUri'] as String?,
      );

  Track copyWith({
    String? url,
    String? localUri,
  }) {
    return Track(
      id: id,
      title: title,
      artist: artist,
      artwork: artwork,
      url: url ?? this.url,
      durationMs: durationMs,
      downloadUrl: downloadUrl,
      localUri: localUri ?? this.localUri,
    );
  }
}
