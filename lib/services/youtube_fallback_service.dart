import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart';
import '../models/music_model.dart';

class YouTubeFallbackService {
  static final YoutubeExplode _yt = YoutubeExplode();

  /// Search for alternative versions of a track when the original fails to play
  static Future<MusicTrack?> findAlternativeTrack(MusicTrack originalTrack) async {
    try {
      if (kDebugMode) {
        print('🔍 Searching for alternative version of: ${originalTrack.title}');
      }

      // Extract search terms from the original track
      final searchQuery = _buildSearchQuery(originalTrack);
      
      if (kDebugMode) {
        print('🔍 Search query: $searchQuery');
      }

      // Search for videos using youtube_explode_dart
      final searchResults = <Video>[];
      final searchList = await _yt.search.search(searchQuery);
      
      // Take up to 10 video results
      for (final result in searchList) {
        searchResults.add(result);
        if (searchResults.length >= 10) break;
      }
      
      if (searchResults.isEmpty) {
        if (kDebugMode) {
          print('❌ No search results found for: $searchQuery');
        }
        return null;
      }

      // Find the best matching video
      final bestMatch = _findBestMatch(originalTrack, searchResults);
      
      if (bestMatch == null) {
        if (kDebugMode) {
          print('❌ No suitable alternative found for: ${originalTrack.title}');
        }
        return null;
      }

      // Create a new MusicTrack from the alternative video
      final alternativeTrack = await _createTrackFromVideo(bestMatch, originalTrack);
      
      if (kDebugMode) {
        print('✅ Found alternative: ${alternativeTrack.title} by ${alternativeTrack.artist}');
        print('🔗 Alternative URL: ${alternativeTrack.webpageUrl}');
      }

      return alternativeTrack;

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding alternative track: $e');
      }
      return null;
    }
  }

  /// Build search query from track metadata
  static String _buildSearchQuery(MusicTrack track) {
    final title = _cleanTitle(track.title);
    final artist = _cleanArtist(track.artist);
    
    // Create search query with different strategies
    if (artist.isNotEmpty && title.isNotEmpty) {
      return '$artist $title';
    } else if (title.isNotEmpty) {
      return title;
    } else {
      // Fallback to original title if cleaning removed everything
      return track.title;
    }
  }

  /// Clean the title by removing common unwanted elements
  static String _cleanTitle(String title) {
    String cleaned = title;
    
    // Remove common patterns that might interfere with search
    final patterns = [
      RegExp(r'\(Official.*?\)', caseSensitive: false),
      RegExp(r'\[Official.*?\]', caseSensitive: false),
      RegExp(r'\(Lyric.*?\)', caseSensitive: false),
      RegExp(r'\[Lyric.*?\]', caseSensitive: false),
      RegExp(r'\(Audio.*?\)', caseSensitive: false),
      RegExp(r'\[Audio.*?\]', caseSensitive: false),
      RegExp(r'\(HD\)', caseSensitive: false),
      RegExp(r'\[HD\]', caseSensitive: false),
      RegExp(r'\(4K\)', caseSensitive: false),
      RegExp(r'\[4K\]', caseSensitive: false),
      RegExp(r'\(Live.*?\)', caseSensitive: false),
      RegExp(r'\[Live.*?\]', caseSensitive: false),
      RegExp(r'\(feat\..*?\)', caseSensitive: false),
      RegExp(r'\[feat\..*?\]', caseSensitive: false),
      RegExp(r'\(ft\..*?\)', caseSensitive: false),
      RegExp(r'\[ft\..*?\]', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }

  /// Clean the artist name
  static String _cleanArtist(String artist) {
    String cleaned = artist;
    
    // Remove common suffixes
    final patterns = [
      RegExp(r'\s*-\s*Topic$', caseSensitive: false),
      RegExp(r'\s*VEVO$', caseSensitive: false),
      RegExp(r'\s*Official$', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }

  /// Find the best matching video from search results
  static Video? _findBestMatch(MusicTrack originalTrack, List<Video> searchResults) {
    final cleanedOriginalTitle = _cleanTitle(originalTrack.title).toLowerCase();
    final cleanedOriginalArtist = _cleanArtist(originalTrack.artist).toLowerCase();
    
    Video? bestMatch;
    double bestScore = 0.0;
    
    for (final video in searchResults) {
      final videoTitle = video.title.toLowerCase();
      final videoAuthor = video.author.toLowerCase();
      
      // Skip if video is too short (likely not a full song)
      if (video.duration != null && video.duration!.inSeconds < 30) {
        continue;
      }
      
      // Skip if video is too long (likely not a song)
      if (video.duration != null && video.duration!.inSeconds > 600) {
        continue;
      }
      
      double score = 0.0;
      
      // Check title similarity
      if (videoTitle.contains(cleanedOriginalTitle) || 
          cleanedOriginalTitle.contains(videoTitle)) {
        score += 3.0;
      } else {
        // Check for partial title matches
        final titleWords = cleanedOriginalTitle.split(' ');
        int matchingWords = 0;
        for (final word in titleWords) {
          if (word.length > 2 && videoTitle.contains(word)) {
            matchingWords++;
          }
        }
        score += (matchingWords / titleWords.length) * 2.0;
      }
      
      // Check artist/author similarity
      if (cleanedOriginalArtist.isNotEmpty) {
        if (videoAuthor.contains(cleanedOriginalArtist) || 
            cleanedOriginalArtist.contains(videoAuthor)) {
          score += 2.0;
        }
      }
      
      // Prefer videos with "official" in the title or author
      if (videoTitle.contains('official') || videoAuthor.contains('official')) {
        score += 1.0;
      }
      
      // Prefer videos from verified channels (VEVO, Topic, etc.)
      if (videoAuthor.contains('vevo') || videoAuthor.contains('topic')) {
        score += 0.5;
      }
      
      // Slightly prefer videos with reasonable duration (2-6 minutes)
      if (video.duration != null) {
        final durationSeconds = video.duration!.inSeconds;
        if (durationSeconds >= 120 && durationSeconds <= 360) {
          score += 0.3;
        }
      }
      
      if (kDebugMode) {
        print('🎵 Candidate: ${video.title} by ${video.author} (Score: ${score.toStringAsFixed(2)})');
      }
      
      if (score > bestScore && score > 1.0) { // Minimum threshold
        bestScore = score;
        bestMatch = video;
      }
    }
    
    if (kDebugMode && bestMatch != null) {
      print('🏆 Best match: ${bestMatch.title} by ${bestMatch.author} (Score: ${bestScore.toStringAsFixed(2)})');
    }
    
    return bestMatch;
  }

  /// Create a MusicTrack from a Video object
  static Future<MusicTrack> _createTrackFromVideo(Video video, MusicTrack originalTrack) async {
    return MusicTrack(
      id: video.id.value,
      title: video.title,
      artist: video.author,
      album: originalTrack.album,
      duration: video.duration?.inSeconds ?? 0,
      durationString: video.duration?.toString() ?? originalTrack.durationString,
      webpageUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
      thumbnail: video.thumbnails.mediumResUrl,
      // Required fields with sensible defaults
      availability: 'public',
      category: 'Music',
      description: video.description,
      extractor: 'youtube_explode_dart',
      liveStatus: 'not_live',
      posterImage: video.thumbnails.highResUrl,
      source: 'YouTube',
      uploader: video.author,
      // Optional fields
      likeCount: video.engagement.likeCount,
      viewCount: video.engagement.viewCount,
      uploadDate: video.uploadDate?.toIso8601String(),
    );
  }

  /// Validate if an alternative track is playable
  static Future<bool> validateAlternativeTrack(MusicTrack track) async {
    try {
      final videoId = _extractVideoId(track.webpageUrl);
      if (videoId == null) return false;
      
      // Try to get the video manifest to check if it's playable
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;
      
      return audioStreams.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Alternative track validation failed: $e');
      }
      return false;
    }
  }

  /// Extract video ID from YouTube URL
  static String? _extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  /// Clean up resources
  static void dispose() {
    _yt.close();
  }
}
