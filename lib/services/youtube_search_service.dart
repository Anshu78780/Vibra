import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart';
import '../models/music_model.dart';

class YoutubeSearchService {
  static final YoutubeExplode _yt = YoutubeExplode();

  /// Search for music tracks using youtube_explode_dart
  static Future<SearchResponse> searchMusic(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) {
      return SearchResponse(
        query: query,
        resultsCount: 0,
        songs: [],
      );
    }

    try {
      debugPrint('🔍 Searching YouTube for: $query');
      
      // Search for videos using youtube_explode_dart
      final searchResults = <Video>[];
      final searchList = await _yt.search.search(query);
      
      // Take up to the specified limit
      for (final result in searchList) {
        searchResults.add(result);
        if (searchResults.length >= limit) break;
      }
      
      debugPrint('📦 Found ${searchResults.length} videos');
      
      // Convert videos to MusicTrack objects
      final musicTracks = <MusicTrack>[];
      for (final video in searchResults) {
        try {
          // Filter out videos that are likely not music
          if (_isLikelyMusicVideo(video)) {
            final track = await _createTrackFromVideo(video);
            musicTracks.add(track);
          }
        } catch (e) {
          debugPrint('⚠️ Skipping video ${video.title}: $e');
          continue;
        }
      }
      
      debugPrint('🎵 Converted ${musicTracks.length} videos to music tracks');
      
      return SearchResponse(
        query: query,
        resultsCount: musicTracks.length,
        songs: musicTracks,
      );
      
    } catch (e) {
      debugPrint('❌ Error searching YouTube: $e');
      throw Exception('Search failed: $e');
    }
  }

  /// Check if a video is likely to be a music video
  static bool _isLikelyMusicVideo(Video video) {
    final title = video.title.toLowerCase();
    final author = video.author.toLowerCase();
    final duration = video.duration;
    
    // Skip videos that are too short (less than 30 seconds) or too long (more than 20 minutes)
    if (duration != null) {
      final seconds = duration.inSeconds;
      if (seconds < 30 || seconds > 1200) {
        return false;
      }
    }
    
    // Skip videos with typical non-music indicators
    final nonMusicIndicators = [
      'tutorial', 'how to', 'review', 'reaction', 'gameplay', 'walkthrough',
      'interview', 'news', 'documentary', 'trailer', 'commercial', 'ad',
      'unboxing', 'vlog', 'podcast', 'lecture', 'stream', 'live stream',
      'compilation', 'best of', 'top 10', 'funny', 'prank', 'meme'
    ];
    
    for (final indicator in nonMusicIndicators) {
      if (title.contains(indicator)) {
        return false;
      }
    }
    
    // Prefer videos from music-related channels
    final musicChannelIndicators = [
      'vevo', 'topic', 'music', 'records', 'entertainment', 'official',
      'audio', 'sound', 'beats', 'productions'
    ];
    
    bool isFromMusicChannel = false;
    for (final indicator in musicChannelIndicators) {
      if (author.contains(indicator)) {
        isFromMusicChannel = true;
        break;
      }
    }
    
    // Prefer videos with music-related terms in title
    final musicTitleIndicators = [
      'official', 'audio', 'music video', 'mv', 'song', 'track', 'single',
      'album', 'feat', 'ft', 'remix', 'cover', 'acoustic', 'live', 'unplugged'
    ];
    
    bool hasMusicTitle = false;
    for (final indicator in musicTitleIndicators) {
      if (title.contains(indicator)) {
        hasMusicTitle = true;
        break;
      }
    }
    
    // Accept if it's from a music channel OR has music-related title terms
    return isFromMusicChannel || hasMusicTitle;
  }

  /// Create a MusicTrack from a YouTube Video
  static Future<MusicTrack> _createTrackFromVideo(Video video) async {
    // Extract artist and title from video title
    final titleParts = _extractArtistAndTitle(video.title);
    final artist = titleParts['artist'] ?? video.author;
    final title = titleParts['title'] ?? video.title;
    
    return MusicTrack(
      id: video.id.value,
      title: title,
      artist: artist,
      album: '', // Not available from search results
      duration: video.duration?.inSeconds ?? 0,
      durationString: _formatDuration(video.duration),
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
      viewCount: video.engagement.viewCount,
      uploadDate: video.uploadDate?.toIso8601String(),
    );
  }

  /// Extract artist and title from video title using common patterns
  static Map<String, String> _extractArtistAndTitle(String videoTitle) {
    String cleanTitle = videoTitle;
    String? artist;
    String? title;
    
    // Common patterns: "Artist - Title", "Artist: Title", "Title by Artist"
    final patterns = [
      RegExp(r'^(.+?)\s*[-–]\s*(.+?)(?:\s*\(.*\))?(?:\s*\[.*\])?$'),  // Artist - Title
      RegExp(r'^(.+?)\s*:\s*(.+?)(?:\s*\(.*\))?(?:\s*\[.*\])?$'),     // Artist: Title
      RegExp(r'^(.+?)\s+by\s+(.+?)(?:\s*\(.*\))?(?:\s*\[.*\])?$'),    // Title by Artist
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleanTitle);
      if (match != null) {
        if (pattern.pattern.contains('by')) {
          // "Title by Artist" pattern
          title = match.group(1)?.trim();
          artist = match.group(2)?.trim();
        } else {
          // "Artist - Title" or "Artist: Title" pattern
          artist = match.group(1)?.trim();
          title = match.group(2)?.trim();
        }
        break;
      }
    }
    
    // Clean up extracted parts
    if (artist != null) {
      artist = _cleanArtistName(artist);
    }
    if (title != null) {
      title = _cleanSongTitle(title);
    }
    
    return {
      'artist': artist ?? '',
      'title': title ?? cleanTitle,
    };
  }

  /// Clean artist name by removing common suffixes
  static String _cleanArtistName(String artist) {
    String cleaned = artist;
    
    // Remove common suffixes
    final patterns = [
      RegExp(r'\s*-\s*Topic$', caseSensitive: false),
      RegExp(r'\s*VEVO$', caseSensitive: false),
      RegExp(r'\s*Official$', caseSensitive: false),
      RegExp(r'\s*Music$', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    
    return cleaned.trim();
  }

  /// Clean song title by removing common unwanted elements
  static String _cleanSongTitle(String title) {
    String cleaned = title;
    
    // Remove common patterns
    final patterns = [
      RegExp(r'\(Official.*?\)', caseSensitive: false),
      RegExp(r'\[Official.*?\]', caseSensitive: false),
      RegExp(r'\(Music Video\)', caseSensitive: false),
      RegExp(r'\[Music Video\]', caseSensitive: false),
      RegExp(r'\(Audio\)', caseSensitive: false),
      RegExp(r'\[Audio\]', caseSensitive: false),
      RegExp(r'\(Lyric.*?\)', caseSensitive: false),
      RegExp(r'\[Lyric.*?\]', caseSensitive: false),
      RegExp(r'\(HD\)', caseSensitive: false),
      RegExp(r'\[HD\]', caseSensitive: false),
      RegExp(r'\(4K\)', caseSensitive: false),
      RegExp(r'\[4K\]', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }

  /// Format duration for display
  static String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get search suggestions based on YouTube search autocomplete
  static Future<List<String>> getSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Use a simple approach - generate common music-related suggestions
      final suggestions = <String>[];
      final baseQuery = query.trim();
      
      // Add some common music search patterns
      if (baseQuery.length > 2) {
        suggestions.addAll([
          '$baseQuery songs',
          '$baseQuery music',
          '$baseQuery official',
          '$baseQuery audio',
          '$baseQuery playlist',
        ]);
      }
      
      // Limit to 5 suggestions
      return suggestions.take(5).toList();
      
    } catch (e) {
      debugPrint('❌ Error getting suggestions: $e');
      return [];
    }
  }

  /// Get trending/popular music tracks and return MusicApiResponse
  static Future<MusicApiResponse> fetchTrendingMusic({int limit = 50}) async {
    try {
      debugPrint('🔥 Fetching trending music');
      
      // Search for popular music-related terms
      final trendingQueries = [
        'popular songs 2024',
        'trending music',
        'top hits',
        'viral songs',
        'new music',
      ];
      
      final allTracks = <MusicTrack>[];
      
      for (final query in trendingQueries) {
        try {
          final response = await searchMusic(query, limit: limit ~/ trendingQueries.length + 5);
          allTracks.addAll(response.songs);
          
          // Break early if we have enough tracks
          if (allTracks.length >= limit) break;
        } catch (e) {
          debugPrint('⚠️ Error fetching trending for query "$query": $e');
          continue;
        }
      }
      
      // Remove duplicates based on video ID
      final uniqueTracks = <String, MusicTrack>{};
      for (final track in allTracks) {
        uniqueTracks[track.id] = track;
      }
      
      final result = uniqueTracks.values.take(limit).toList();
      debugPrint('🎵 Found ${result.length} trending tracks');
      
      return MusicApiResponse(
        categories: ['Trending', 'Popular', 'New Music'],
        lastUpdated: DateTime.now().toIso8601String(),
        totalResults: result.length,
        trendingMusic: result,
      );
      
    } catch (e) {
      debugPrint('❌ Error fetching trending music: $e');
      throw Exception('Failed to fetch trending music: $e');
    }
  }

  /// Clean up resources
  static void dispose() {
    _yt.close();
  }
}
