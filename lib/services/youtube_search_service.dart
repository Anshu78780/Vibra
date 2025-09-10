import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/music_model.dart';

class YoutubeSearchService {
  static final YoutubeExplode _yt = YoutubeExplode();

  /// Search for music tracks using youtube_explode_dart
  static Future<SearchResponse> searchMusic(String query, {int limit = 40}) async {
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
      debugPrint('🔄 Converting ${searchResults.length} videos to music tracks...');
      
      for (int i = 0; i < searchResults.length; i++) {
        final video = searchResults[i];
        try {
          debugPrint('📹 Processing video ${i + 1}/${searchResults.length}: ${video.title}');
          
          // Create track from all videos (removed music filter to show all results)
          final track = await _createTrackFromVideo(video);
          musicTracks.add(track);
          debugPrint('✅ Added track: ${track.title} - ${track.artist}');
        } catch (e) {
          debugPrint('⚠️ Error with video "${video.title}": $e');
          debugPrint('🔄 Trying basic track creation...');
          // Still try to create a basic track with error handling
          try {
            final basicTrack = _createBasicTrackFromVideo(video);
            if (basicTrack != null) {
              musicTracks.add(basicTrack);
              debugPrint('✅ Added basic track: ${basicTrack.title}');
            } else {
              debugPrint('❌ Basic track creation returned null');
            }
          } catch (e2) {
            debugPrint('❌ Failed to create basic track: $e2');
            debugPrint('🚫 Skipping this video completely');
            continue;
          }
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

  /// Create a MusicTrack from a YouTube Video
  static Future<MusicTrack> _createTrackFromVideo(Video video) async {
    try {
      // Extract artist and title from video title
      final titleParts = _extractArtistAndTitle(video.title);
      final artist = titleParts['artist'] ?? video.author;
      final title = titleParts['title'] ?? video.title;
      
      // Safely get thumbnail URLs
      String thumbnailUrl = '';
      String posterUrl = '';
      try {
        final thumbnails = video.thumbnails;
        thumbnailUrl = thumbnails.mediumResUrl;
        posterUrl = thumbnails.highResUrl;
      } catch (e) {
        debugPrint('⚠️ Error accessing thumbnails: $e');
        // Use fallback thumbnail URLs
        try {
          final thumbnails = video.thumbnails;
          thumbnailUrl = thumbnails.lowResUrl.isNotEmpty ? thumbnails.lowResUrl : 
                        'https://img.youtube.com/vi/${video.id.value}/mqdefault.jpg';
          posterUrl = thumbnails.standardResUrl.isNotEmpty ? thumbnails.standardResUrl : 
                     'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg';
        } catch (e2) {
          debugPrint('⚠️ Error accessing fallback thumbnails: $e2');
          thumbnailUrl = 'https://img.youtube.com/vi/${video.id.value}/mqdefault.jpg';
          posterUrl = 'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg';
        }
      }
      
      // Safely get engagement data
      int? viewCount;
      try {
        viewCount = video.engagement.viewCount;
      } catch (e) {
        debugPrint('⚠️ Error accessing engagement: $e');
      }
      
      return MusicTrack(
        id: video.id.value,
        title: title,
        artist: artist,
        album: '', 
        duration: video.duration?.inSeconds ?? 0,
        durationString: _formatDuration(video.duration),
        webpageUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
        thumbnail: thumbnailUrl,
        availability: 'public',
        category: 'Music',
        description: video.description,
        extractor: 'youtube_explode_dart',
        liveStatus: 'not_live',
        posterImage: posterUrl,
        source: 'YouTube',
        uploader: video.author,
        viewCount: viewCount,
        uploadDate: video.uploadDate?.toIso8601String(),
      );
    } catch (e) {
      debugPrint('❌ Error in _createTrackFromVideo: $e');
      rethrow;
    }
  }

  /// Create a basic MusicTrack from a YouTube Video with extensive error handling
  static MusicTrack? _createBasicTrackFromVideo(Video video) {
    try {
      // Basic video properties should always be available
      final videoId = video.id.value;
      final videoTitle = video.title;
      final videoAuthor = video.author;
      final videoDescription = video.description;
      
      if (videoId.isEmpty) {
        debugPrint('⚠️ Video ID is empty, skipping');
        return null;
      }
      
      // Safely get duration
      int durationSeconds = 0;
      String durationString = '0:00';
      try {
        if (video.duration != null) {
          durationSeconds = video.duration!.inSeconds;
          durationString = _formatDuration(video.duration);
        }
      } catch (e) {
        debugPrint('⚠️ Error getting duration: $e');
      }
      
      // Safely get thumbnails - this is where the error might occur
      String thumbnailUrl = '';
      String posterUrl = '';
      try {
        final thumbnails = video.thumbnails;
        // Try different thumbnail qualities
        if (thumbnails.mediumResUrl.isNotEmpty) {
          thumbnailUrl = thumbnails.mediumResUrl;
        } else if (thumbnails.standardResUrl.isNotEmpty) {
          thumbnailUrl = thumbnails.standardResUrl;
        } else if (thumbnails.lowResUrl.isNotEmpty) {
          thumbnailUrl = thumbnails.lowResUrl;
        }
        
        // For poster, try high quality first
        if (thumbnails.highResUrl.isNotEmpty) {
          posterUrl = thumbnails.highResUrl;
        } else if (thumbnails.maxResUrl.isNotEmpty) {
          posterUrl = thumbnails.maxResUrl;
        } else {
          posterUrl = thumbnailUrl; // Fallback to thumbnail
        }
      } catch (e) {
        debugPrint('⚠️ Error getting thumbnails: $e');
        // Create fallback thumbnail URL
        thumbnailUrl = 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
        posterUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      }
      
      // Safely get engagement data
      int? viewCount;
      try {
        viewCount = video.engagement.viewCount;
      } catch (e) {
        debugPrint('⚠️ Error getting view count: $e');
      }
      
      // Safely get upload date
      String? uploadDate;
      try {
        uploadDate = video.uploadDate?.toIso8601String();
      } catch (e) {
        debugPrint('⚠️ Error getting upload date: $e');
      }
      
      // Extract artist and title with fallbacks
      final titleParts = _extractArtistAndTitle(videoTitle);
      final artist = titleParts['artist'] ?? videoAuthor;
      final title = titleParts['title'] ?? videoTitle;
      
      return MusicTrack(
        id: videoId,
        title: title,
        artist: artist,
        album: '', 
        duration: durationSeconds,
        durationString: durationString,
        webpageUrl: 'https://www.youtube.com/watch?v=$videoId',
        thumbnail: thumbnailUrl,
        availability: 'public',
        category: 'Music',
        description: videoDescription,
        extractor: 'youtube_explode_dart',
        liveStatus: 'not_live',
        posterImage: posterUrl,
        source: 'YouTube',
        uploader: videoAuthor,
        viewCount: viewCount,
        uploadDate: uploadDate,
      );
    } catch (e) {
      debugPrint('❌ Error creating basic track: $e');
      return null;
    }
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

  /// Get search suggestions using Google's YouTube search suggestions API
  static Future<List<String>> getSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Use Google's YouTube search suggestions API
      final encodedQuery = Uri.encodeComponent(query.trim());
      final url = 'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=$encodedQuery';
      
      debugPrint('🔍 Fetching YouTube suggestions for: $query');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        // The response is in JSONP format: ["query", ["suggestion1", "suggestion2", ...]]
        final jsonString = response.body;
        final List<dynamic> data = json.decode(jsonString);
        
        if (data.length > 1 && data[1] is List) {
          final List<dynamic> suggestions = data[1];
          final List<String> result = suggestions
              .where((suggestion) => suggestion is String)
              .cast<String>()
              .where((suggestion) => suggestion.isNotEmpty)
              .take(8) // Limit to 8 suggestions
              .toList();
          
          debugPrint('✅ Found ${result.length} YouTube suggestions');
          return result;
        }
      } else {
        debugPrint('⚠️ YouTube suggestions API request failed with status: ${response.statusCode}');
      }
      
      // Fallback to basic suggestions if API fails
      return _getFallbackSuggestions(query);
      
    } catch (e) {
      debugPrint('❌ Error getting YouTube suggestions: $e');
      return _getFallbackSuggestions(query);
    }
  }

  /// Fallback suggestions when the YouTube API is unavailable
  static List<String> _getFallbackSuggestions(String query) {
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
        '$baseQuery lyrics',
        '$baseQuery live',
        '$baseQuery remix',
      ]);
    }
    
    // Limit to 6 suggestions
    return suggestions.take(6).toList();
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
