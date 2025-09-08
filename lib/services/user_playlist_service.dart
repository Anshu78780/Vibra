import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/music_model.dart';
import '../services/playlist_songs_service.dart';

class PlaylistCache {
  final List<MusicTrack> songs;
  final DateTime cachedAt;
  final int songsCount;

  PlaylistCache({
    required this.songs,
    required this.cachedAt,
    required this.songsCount,
  });

  factory PlaylistCache.fromJson(Map<String, dynamic> json) {
    return PlaylistCache(
      songs: (json['songs'] as List)
          .map((songJson) => MusicTrack.fromJson(songJson))
          .toList(),
      cachedAt: DateTime.parse(json['cachedAt']),
      songsCount: json['songsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songs': songs.map((song) => song.toJson()).toList(),
      'cachedAt': cachedAt.toIso8601String(),
      'songsCount': songsCount,
    };
  }

  bool isExpired({Duration expiration = const Duration(hours: 6)}) {
    return DateTime.now().difference(cachedAt) > expiration;
  }
}

class UserPlaylist {
  final String id;
  final String name;
  final String youtubeUrl;
  final String playlistId;
  final DateTime createdAt;

  UserPlaylist({
    required this.id,
    required this.name,
    required this.youtubeUrl,
    required this.playlistId,
    required this.createdAt,
  });

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    return UserPlaylist(
      id: json['id'],
      name: json['name'],
      youtubeUrl: json['youtubeUrl'],
      playlistId: json['playlistId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'youtubeUrl': youtubeUrl,
      'playlistId': playlistId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class UserPlaylistService {
  static const String _storageKey = 'user_playlists';
  static const String _cacheKey = 'playlist_songs_cache';
  static final Map<String, UserPlaylist> _userPlaylists = {};
  static final Map<String, PlaylistCache> _playlistCache = {};

  // Load cached playlists from SharedPreferences
  static Future<void> loadCachedPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load playlists
      final playlistsJson = prefs.getStringList(_storageKey) ?? [];
      _userPlaylists.clear();
      for (final playlistJson in playlistsJson) {
        final playlistMap = json.decode(playlistJson);
        final playlist = UserPlaylist.fromJson(playlistMap);
        _userPlaylists[playlist.id] = playlist;
      }
      
      // Load playlist songs cache
      await _loadPlaylistSongsCache();
      
      debugPrint('Loaded ${_userPlaylists.length} user playlists and ${_playlistCache.length} cached song lists from storage');
    } catch (e) {
      debugPrint('Error loading user playlists from cache: $e');
    }
  }

  // Load playlist songs cache from SharedPreferences
  static Future<void> _loadPlaylistSongsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getStringList(_cacheKey) ?? [];
      
      _playlistCache.clear();
      for (final cacheItemJson in cacheJson) {
        final cacheMap = json.decode(cacheItemJson);
        final playlistId = cacheMap['playlistId'] as String;
        final cacheData = cacheMap['cache'] as Map<String, dynamic>;
        final cache = PlaylistCache.fromJson(cacheData);
        _playlistCache[playlistId] = cache;
      }
      
      debugPrint('Loaded ${_playlistCache.length} playlist songs from cache');
    } catch (e) {
      debugPrint('Error loading playlist songs cache: $e');
      _playlistCache.clear();
    }
  }

  // Save playlist songs cache to SharedPreferences
  static Future<void> _savePlaylistSongsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = _playlistCache.entries.map((entry) {
        return json.encode({
          'playlistId': entry.key,
          'cache': entry.value.toJson(),
        });
      }).toList();
      
      await prefs.setStringList(_cacheKey, cacheJson);
      debugPrint('Saved ${_playlistCache.length} playlist song caches to storage');
    } catch (e) {
      debugPrint('Error saving playlist songs cache: $e');
    }
  }

  // Save playlists to SharedPreferences
  static Future<void> _savePlaylistsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = _userPlaylists.values.map((playlist) {
        return json.encode(playlist.toJson());
      }).toList();
      
      await prefs.setStringList(_storageKey, playlistsJson);
      debugPrint('Saved ${_userPlaylists.length} user playlists to cache');
    } catch (e) {
      debugPrint('Error saving user playlists to cache: $e');
    }
  }

  // Extract playlist ID from YouTube URL
  static String? extractPlaylistId(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Handle different YouTube playlist URL formats
      if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
        // Format: https://www.youtube.com/playlist?list=PLiJ19Xxebz3nkJ7Rg1vgHzu-nSLmSig7t
        if (uri.queryParameters.containsKey('list')) {
          final playlistId = uri.queryParameters['list'];
          if (playlistId != null && playlistId.isNotEmpty) {
            return playlistId;
          }
        }
        
        // Format: https://music.youtube.com/playlist?list=PLiJ19Xxebz3nkJ7Rg1vgHzu-nSLmSig7t
        if (uri.host.contains('music.youtube.com') && uri.queryParameters.containsKey('list')) {
          final playlistId = uri.queryParameters['list'];
          if (playlistId != null && playlistId.isNotEmpty) {
            return playlistId;
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting playlist ID from URL: $e');
    }
    
    return null;
  }

  // Validate playlist by fetching songs from API
  static Future<bool> validatePlaylist(String playlistId) async {
    try {
      final songs = await PlaylistSongsService.getPlaylistSongs(playlistId, limit: 1);
      return songs.isNotEmpty;
    } catch (e) {
      debugPrint('Error validating playlist: $e');
      return false;
    }
  }

  // Add a new user playlist
  static Future<String?> addUserPlaylist(String name, String youtubeUrl) async {
    try {
      // Extract playlist ID
      final playlistId = extractPlaylistId(youtubeUrl);
      if (playlistId == null) {
        throw Exception('Invalid YouTube playlist URL');
      }

      // Validate playlist
      final isValid = await validatePlaylist(playlistId);
      if (!isValid) {
        throw Exception('Playlist not found or empty');
      }

      // Create playlist object
      final playlist = UserPlaylist(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim(),
        youtubeUrl: youtubeUrl.trim(),
        playlistId: playlistId,
        createdAt: DateTime.now(),
      );

      // Check if playlist already exists
      final existingPlaylist = _userPlaylists.values.firstWhere(
        (p) => p.playlistId == playlistId,
        orElse: () => playlist,
      );

      if (existingPlaylist.id != playlist.id) {
        throw Exception('Playlist already exists');
      }

      // Save playlist
      _userPlaylists[playlist.id] = playlist;
      await _savePlaylistsToCache();

      debugPrint('Added user playlist: ${playlist.name}');
      return null; // Success
    } catch (e) {
      debugPrint('Error adding user playlist: $e');
      return e.toString();
    }
  }

  // Remove a user playlist
  static Future<void> removeUserPlaylist(String playlistId) async {
    _userPlaylists.remove(playlistId);
    await _savePlaylistsToCache();
    
    // Also remove cached songs for this playlist
    await clearPlaylistCache(playlistId);
  }

  // Get all user playlists
  static List<UserPlaylist> getUserPlaylists() {
    final playlists = _userPlaylists.values.toList();
    playlists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return playlists;
  }

  // Get playlist songs with caching
  static Future<List<MusicTrack>> getPlaylistSongs(String playlistId, {bool forceRefresh = false}) async {
    try {
      // Check cache first if not forcing refresh
      if (!forceRefresh && _playlistCache.containsKey(playlistId)) {
        final cache = _playlistCache[playlistId]!;
        
        // Return cached data if not expired
        if (!cache.isExpired()) {
          debugPrint('📦 Using cached songs for playlist $playlistId (${cache.songs.length} songs)');
          return cache.songs;
        } else {
          debugPrint('⏰ Cache expired for playlist $playlistId, fetching fresh data');
        }
      }
      
      // Fetch fresh data from API
      debugPrint('🌐 Fetching fresh songs for playlist $playlistId');
      final songs = await PlaylistSongsService.getPlaylistSongs(playlistId);
      
      if (songs.isNotEmpty) {
        // Cache the fetched songs
        final cache = PlaylistCache(
          songs: songs,
          cachedAt: DateTime.now(),
          songsCount: songs.length,
        );
        _playlistCache[playlistId] = cache;
        
        // Save cache to persistent storage
        await _savePlaylistSongsCache();
        
        debugPrint('💾 Cached ${songs.length} songs for playlist $playlistId');
      }
      
      return songs;
    } catch (e) {
      debugPrint('❌ Error getting playlist songs: $e');
      
      // Try to return cached data even if expired, as fallback
      if (_playlistCache.containsKey(playlistId)) {
        final cache = _playlistCache[playlistId]!;
        debugPrint('🔄 API failed, using cached data as fallback (${cache.songs.length} songs)');
        return cache.songs;
      }
      
      return [];
    }
  }

  // Clear cache for a specific playlist
  static Future<void> clearPlaylistCache(String playlistId) async {
    _playlistCache.remove(playlistId);
    await _savePlaylistSongsCache();
    debugPrint('🗑️ Cleared cache for playlist $playlistId');
  }

  // Clear all playlist caches
  static Future<void> clearAllPlaylistCaches() async {
    _playlistCache.clear();
    await _savePlaylistSongsCache();
    debugPrint('🗑️ Cleared all playlist caches');
  }

  // Get cache info for a playlist
  static Map<String, dynamic>? getPlaylistCacheInfo(String playlistId) {
    if (!_playlistCache.containsKey(playlistId)) {
      return null;
    }
    
    final cache = _playlistCache[playlistId]!;
    return {
      'cachedAt': cache.cachedAt,
      'songsCount': cache.songsCount,
      'isExpired': cache.isExpired(),
      'ageHours': DateTime.now().difference(cache.cachedAt).inHours,
    };
  }

  // Clear all user playlists
  static Future<void> clearAllPlaylists() async {
    _userPlaylists.clear();
    await _savePlaylistsToCache();
    
    // Also clear all cached songs
    await clearAllPlaylistCaches();
  }

  // Add song to a user playlist
  static Future<bool> addSongToPlaylist(String playlistId, MusicTrack song) async {
    try {
      // Get current playlist songs
      final currentSongs = await getPlaylistSongs(playlistId);
      
      // Check if song already exists
      final songExists = currentSongs.any((track) => track.webpageUrl == song.webpageUrl);
      if (songExists) {
        debugPrint('🚫 Song already exists in playlist $playlistId');
        return false;
      }
      
      // Add song to the beginning of the list
      final updatedSongs = [song, ...currentSongs];
      
      // Update cache
      final cache = PlaylistCache(
        songs: updatedSongs,
        cachedAt: DateTime.now(),
        songsCount: updatedSongs.length,
      );
      _playlistCache[playlistId] = cache;
      
      // Save cache to persistent storage
      await _savePlaylistSongsCache();
      
      debugPrint('✅ Added song "${song.title}" to playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding song to playlist $playlistId: $e');
      return false;
    }
  }

  // Remove song from a user playlist
  static Future<bool> removeSongFromPlaylist(String playlistId, String songWebpageUrl) async {
    try {
      // Get current playlist songs
      final currentSongs = await getPlaylistSongs(playlistId);
      
      // Remove the song
      final updatedSongs = currentSongs.where((track) => track.webpageUrl != songWebpageUrl).toList();
      
      // Check if song was actually removed
      if (updatedSongs.length == currentSongs.length) {
        debugPrint('🚫 Song not found in playlist $playlistId');
        return false;
      }
      
      // Update cache
      final cache = PlaylistCache(
        songs: updatedSongs,
        cachedAt: DateTime.now(),
        songsCount: updatedSongs.length,
      );
      _playlistCache[playlistId] = cache;
      
      // Save cache to persistent storage
      await _savePlaylistSongsCache();
      
      debugPrint('✅ Removed song from playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing song from playlist $playlistId: $e');
      return false;
    }
  }

  // Check if song exists in a playlist
  static Future<bool> isSongInPlaylist(String playlistId, String songWebpageUrl) async {
    try {
      final songs = await getPlaylistSongs(playlistId);
      return songs.any((track) => track.webpageUrl == songWebpageUrl);
    } catch (e) {
      debugPrint('❌ Error checking song in playlist $playlistId: $e');
      return false;
    }
  }

  // Get playlists that contain a specific song
  static Future<List<UserPlaylist>> getPlaylistsContainingSong(String songWebpageUrl) async {
    final playlistsWithSong = <UserPlaylist>[];
    
    for (final playlist in _userPlaylists.values) {
      try {
        final songs = await getPlaylistSongs(playlist.playlistId);
        if (songs.any((track) => track.webpageUrl == songWebpageUrl)) {
          playlistsWithSong.add(playlist);
        }
      } catch (e) {
        debugPrint('❌ Error checking playlist ${playlist.name}: $e');
      }
    }
    
    return playlistsWithSong;
  }

  // Refresh playlist songs cache
  static Future<List<MusicTrack>> refreshPlaylistSongs(String playlistId) async {
    debugPrint('🔄 Force refreshing songs for playlist $playlistId');
    return await getPlaylistSongs(playlistId, forceRefresh: true);
  }

  // Get cache statistics
  static Map<String, dynamic> getCacheStatistics() {
    int totalCachedSongs = 0;
    int expiredCaches = 0;
    
    for (final cache in _playlistCache.values) {
      totalCachedSongs += cache.songsCount;
      if (cache.isExpired()) {
        expiredCaches++;
      }
    }
    
    return {
      'totalPlaylistsCached': _playlistCache.length,
      'totalCachedSongs': totalCachedSongs,
      'expiredCaches': expiredCaches,
      'validCaches': _playlistCache.length - expiredCaches,
    };
  }
}
