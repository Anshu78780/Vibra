import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_model.dart';
import '../models/playlist_model.dart';

class CacheService {
  static const String _trendingMusicKey = 'trending_music_cache';
  static const String _trendingPlaylistsKey = 'trending_playlists_cache';
  static const String _trendingMusicTimestampKey = 'trending_music_timestamp';
  static const String _trendingPlaylistsTimestampKey = 'trending_playlists_timestamp';
  
  // Cache duration: 2 hours
  static const Duration cacheDuration = Duration(hours: 2);
  
  /// Check if cached data is still valid (not expired)
  static bool _isCacheValid(int? timestamp) {
    if (timestamp == null) return false;
    
    final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(cachedTime);
    
    return difference < cacheDuration;
  }
  
  /// Cache trending music data
  static Future<void> cacheTrendingMusic(List<MusicTrack> tracks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Convert tracks to JSON
      final tracksJson = tracks.map((track) => track.toJson()).toList();
      final jsonString = jsonEncode(tracksJson);
      
      // Store data and timestamp
      await prefs.setString(_trendingMusicKey, jsonString);
      await prefs.setInt(_trendingMusicTimestampKey, now);
      
      print('✅ Cached ${tracks.length} trending music tracks');
    } catch (e) {
      print('❌ Error caching trending music: $e');
    }
  }
  
  /// Get cached trending music data
  static Future<List<MusicTrack>?> getCachedTrendingMusic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_trendingMusicTimestampKey);
      
      if (!_isCacheValid(timestamp)) {
        print('🔄 Trending music cache expired');
        return null;
      }
      
      final jsonString = prefs.getString(_trendingMusicKey);
      if (jsonString == null) return null;
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final tracks = jsonList
          .map((json) => MusicTrack.fromJson(json as Map<String, dynamic>))
          .toList();
      
      print('✅ Retrieved ${tracks.length} cached trending music tracks');
      return tracks;
    } catch (e) {
      print('❌ Error retrieving cached trending music: $e');
      return null;
    }
  }
  
  /// Cache trending playlists data
  static Future<void> cacheTrendingPlaylists(List<Playlist> playlists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Convert playlists to JSON
      final playlistsJson = playlists.map((playlist) => playlist.toJson()).toList();
      final jsonString = jsonEncode(playlistsJson);
      
      // Store data and timestamp
      await prefs.setString(_trendingPlaylistsKey, jsonString);
      await prefs.setInt(_trendingPlaylistsTimestampKey, now);
      
      print('✅ Cached ${playlists.length} trending playlists');
    } catch (e) {
      print('❌ Error caching trending playlists: $e');
    }
  }
  
  /// Get cached trending playlists data
  static Future<List<Playlist>?> getCachedTrendingPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_trendingPlaylistsTimestampKey);
      
      if (!_isCacheValid(timestamp)) {
        print('🔄 Trending playlists cache expired');
        return null;
      }
      
      final jsonString = prefs.getString(_trendingPlaylistsKey);
      if (jsonString == null) return null;
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final playlists = jsonList
          .map((json) => Playlist.fromJson(json as Map<String, dynamic>))
          .toList();
      
      print('✅ Retrieved ${playlists.length} cached trending playlists');
      return playlists;
    } catch (e) {
      print('❌ Error retrieving cached trending playlists: $e');
      return null;
    }
  }
  
  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_trendingMusicKey),
        prefs.remove(_trendingPlaylistsKey),
        prefs.remove(_trendingMusicTimestampKey),
        prefs.remove(_trendingPlaylistsTimestampKey),
      ]);
      print('✅ Cache cleared successfully');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Get cache size information
  static Future<Map<String, dynamic>> getCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final musicData = prefs.getString(_trendingMusicKey);
      final playlistsData = prefs.getString(_trendingPlaylistsKey);
      
      final musicSize = musicData?.length ?? 0;
      final playlistsSize = playlistsData?.length ?? 0;
      final totalSize = musicSize + playlistsSize;
      
      return {
        'musicSize': musicSize,
        'playlistsSize': playlistsSize,
        'totalSize': totalSize,
        'totalSizeKB': (totalSize / 1024).toStringAsFixed(2),
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('❌ Error getting cache size: $e');
      return {'totalSize': 0};
    }
  }
  
  /// Get cache status for debugging
  static Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final musicTimestamp = prefs.getInt(_trendingMusicTimestampKey);
      final playlistsTimestamp = prefs.getInt(_trendingPlaylistsTimestampKey);
      
      final musicValid = _isCacheValid(musicTimestamp);
      final playlistsValid = _isCacheValid(playlistsTimestamp);
      
      final musicAge = musicTimestamp != null 
          ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(musicTimestamp))
          : null;
      
      final playlistsAge = playlistsTimestamp != null 
          ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(playlistsTimestamp))
          : null;
      
      return {
        'trendingMusic': {
          'cached': musicTimestamp != null,
          'valid': musicValid,
          'age': musicAge?.toString(),
        },
        'trendingPlaylists': {
          'cached': playlistsTimestamp != null,
          'valid': playlistsValid,
          'age': playlistsAge?.toString(),
        },
      };
    } catch (e) {
      print('❌ Error getting cache status: $e');
      return {};
    }
  }
}
