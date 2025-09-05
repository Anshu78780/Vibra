class Playlist {
  final String playlistId;
  final String title;
  final String description;
  final String thumbnail;
  final String url;
  final String section;

  Playlist({
    required this.playlistId,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.url,
    required this.section,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      playlistId: json['playlistId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      url: json['url'] ?? '',
      section: json['section'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playlistId': playlistId,
      'title': title,
      'description': description,
      'thumbnail': thumbnail,
      'url': url,
      'section': section,
    };
  }
}
