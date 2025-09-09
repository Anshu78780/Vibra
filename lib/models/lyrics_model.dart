class LyricsData {
  final LyricsMetadata metadata;
  final List<LyricsLine> lyrics;
  final String type; // 'synced', 'plain', or 'none'

  LyricsData({
    required this.metadata,
    required this.lyrics,
    required this.type,
  });

  factory LyricsData.fromJson(Map<String, dynamic> json) {
    return LyricsData(
      metadata: LyricsMetadata.fromJson(json['metadata'] ?? {}),
      lyrics: (json['lyrics'] as List<dynamic>?)
              ?.map((lyric) => LyricsLine.fromJson(lyric as Map<String, dynamic>))
              .toList() ??
          [],
      type: json['type'] ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'lyrics': lyrics.map((lyric) => lyric.toJson()).toList(),
      'type': type,
    };
  }

  bool get hasSyncedLyrics => type == 'synced' && lyrics.isNotEmpty;
  bool get hasPlainLyrics => metadata.plainLyrics.isNotEmpty;
  bool get hasAnyLyrics => hasSyncedLyrics || hasPlainLyrics;
}

class LyricsMetadata {
  final int id;
  final String name;
  final String trackName;
  final String artistName;
  final String albumName;
  final int duration;
  final bool instrumental;
  final String plainLyrics;
  final String syncedLyrics;

  LyricsMetadata({
    required this.id,
    required this.name,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.instrumental,
    required this.plainLyrics,
    required this.syncedLyrics,
  });

  factory LyricsMetadata.fromJson(Map<String, dynamic> json) {
    return LyricsMetadata(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      trackName: json['trackName'] ?? '',
      artistName: json['artistName'] ?? '',
      albumName: json['albumName'] ?? '',
      duration: json['duration'] ?? 0,
      instrumental: json['instrumental'] ?? false,
      plainLyrics: json['plainLyrics'] ?? '',
      syncedLyrics: json['syncedLyrics'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trackName': trackName,
      'artistName': artistName,
      'albumName': albumName,
      'duration': duration,
      'instrumental': instrumental,
      'plainLyrics': plainLyrics,
      'syncedLyrics': syncedLyrics,
    };
  }
}

class LyricsLine {
  final String text;
  final double startTime;

  LyricsLine({
    required this.text,
    required this.startTime,
  });

  factory LyricsLine.fromJson(Map<String, dynamic> json) {
    return LyricsLine(
      text: json['text'] ?? '',
      startTime: (json['startTime'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'startTime': startTime,
    };
  }

  @override
  String toString() => 'LyricsLine(text: "$text", startTime: $startTime)';
}
