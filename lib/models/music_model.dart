import '../utils/image_utils.dart';

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? audioUrl;
  final String availability;
  final String category;
  final String description;
  final int duration;
  final String durationString;
  final String extractor;
  final int? likeCount;
  final String liveStatus;
  final String posterImage;
  final String source;
  final String thumbnail;
  final String? uploadDate;
  final String uploader;
  final int? viewCount;
  final String webpageUrl;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.audioUrl,
    required this.availability,
    required this.category,
    required this.description,
    required this.duration,
    required this.durationString,
    required this.extractor,
    this.likeCount,
    required this.liveStatus,
    required this.posterImage,
    required this.source,
    required this.thumbnail,
    this.uploadDate,
    required this.uploader,
    this.viewCount,
    required this.webpageUrl,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Title',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      album: json['album']?.toString() ?? 'Unknown Album',
      audioUrl: json['audio_url']?.toString(),
      availability: json['availability']?.toString() ?? 'unknown',
      category: json['category']?.toString() ?? 'general',
      description: json['description']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] : int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      durationString: json['duration_string']?.toString() ?? '00:00',
      extractor: json['extractor']?.toString() ?? '',
      likeCount: json['like_count'] is int ? json['like_count'] : int.tryParse(json['like_count']?.toString() ?? ''),
      liveStatus: json['live_status']?.toString() ?? 'not_live',
      posterImage: ImageUtils.enhanceImageQuality(json['poster_image']?.toString() ?? ''),
      source: json['source']?.toString() ?? '',
      thumbnail: ImageUtils.enhanceImageQuality(json['thumbnail']?.toString() ?? ''),
      uploadDate: json['upload_date']?.toString(),
      uploader: json['uploader']?.toString() ?? 'Unknown Uploader',
      viewCount: json['view_count'] is int ? json['view_count'] : int.tryParse(json['view_count']?.toString() ?? ''),
      webpageUrl: json['webpage_url']?.toString() ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'audio_url': audioUrl,
      'availability': availability,
      'category': category,
      'description': description,
      'duration': duration,
      'duration_string': durationString,
      'extractor': extractor,
      'like_count': likeCount,
      'live_status': liveStatus,
      'poster_image': posterImage,
      'source': source,
      'thumbnail': thumbnail,
      'upload_date': uploadDate,
      'uploader': uploader,
      'view_count': viewCount,
      'webpage_url': webpageUrl,
    };
  }
}

class MusicApiResponse {
  final List<String> categories;
  final String lastUpdated;
  final int totalResults;
  final List<MusicTrack> trendingMusic;

  MusicApiResponse({
    required this.categories,
    required this.lastUpdated,
    required this.totalResults,
    required this.trendingMusic,
  });

  factory MusicApiResponse.fromJson(Map<String, dynamic> json) {
    print('Parsing MusicApiResponse from JSON: ${json.keys}');
    
    final data = json['data'] as Map<String, dynamic>? ?? {};
    print('Data keys: ${data.keys}');
    
    final categoriesList = data['categories'];
    final categories = categoriesList is List 
        ? categoriesList.map((e) => e.toString()).toList() 
        : <String>[];
    
    final trendingMusicList = data['trending_music'];
    final trendingMusic = <MusicTrack>[];
    
    if (trendingMusicList is List) {
      for (final item in trendingMusicList) {
        if (item is Map<String, dynamic>) {
          try {
            trendingMusic.add(MusicTrack.fromJson(item));
          } catch (e) {
            print('Error parsing track: $e');
            // Continue with other tracks even if one fails
          }
        }
      }
    }
    
    print('Parsed ${trendingMusic.length} tracks');
    
    return MusicApiResponse(
      categories: categories,
      lastUpdated: data['last_updated']?.toString() ?? 'unknown',
      totalResults: data['total_results'] is int 
          ? data['total_results'] 
          : int.tryParse(data['total_results']?.toString() ?? '0') ?? 0,
      trendingMusic: trendingMusic,
    );
  }
}

class SearchResponse {
  final String query;
  final int resultsCount;
  final List<MusicTrack> songs;

  SearchResponse({
    required this.query,
    required this.resultsCount,
    required this.songs,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    print('Parsing SearchResponse from JSON: ${json.keys}');
    
    final songsList = json['songs'];
    final songs = <MusicTrack>[];
    
    if (songsList is List) {
      for (final item in songsList) {
        if (item is Map<String, dynamic>) {
          try {
            songs.add(MusicTrack.fromJson(item));
          } catch (e) {
            print('Error parsing search track: $e');
            // Continue with other tracks even if one fails
          }
        }
      }
    }
    
    print('Parsed ${songs.length} search results');
    
    return SearchResponse(
      query: json['query']?.toString() ?? '',
      resultsCount: json['results_count'] is int 
          ? json['results_count'] 
          : int.tryParse(json['results_count']?.toString() ?? '0') ?? 0,
      songs: songs,
    );
  }
}
