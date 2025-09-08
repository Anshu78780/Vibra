import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LikedPlaylist {
  final String id;
  final String title;
  final String channelName;
  final String playlistUrl;
  final String thumbnailUrl;
  final DateTime likedAt;
  final String source; // 'trending' or 'user'

  LikedPlaylist({
    required this.id,
    required this.title,
    required this.channelName,
    required this.playlistUrl,
    required this.thumbnailUrl,
    required this.likedAt,
    required this.source,
  });

  factory LikedPlaylist.fromJson(Map<String, dynamic> json) {
    return LikedPlaylist(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      channelName: json['channelName'] ?? '',
      playlistUrl: json['playlistUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      likedAt: DateTime.parse(json['likedAt']),
      source: json['source'] ?? 'trending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'channelName': channelName,
      'playlistUrl': playlistUrl,
      'thumbnailUrl': thumbnailUrl,
      'likedAt': likedAt.toIso8601String(),
      'source': source,
    };
  }
}

class LikedPlaylistsService {
  static const String _storageKey = 'liked_playlists';
  static final Map<String, LikedPlaylist> _likedPlaylists = {};

  // Load liked playlists from storage
  static Future<void> loadLikedPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = prefs.getStringList(_storageKey) ?? [];
      
      _likedPlaylists.clear();
      for (final playlistJson in playlistsJson) {
        final playlistMap = json.decode(playlistJson);
        final playlist = LikedPlaylist.fromJson(playlistMap);
        _likedPlaylists[playlist.id] = playlist;
      }
      
      debugPrint('📚 Loaded ${_likedPlaylists.length} liked playlists from storage');
    } catch (e) {
      debugPrint('❌ Error loading liked playlists: $e');
    }
  }

  // Save liked playlists to storage
  static Future<void> _saveLikedPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = _likedPlaylists.values.map((playlist) {
        return json.encode(playlist.toJson());
      }).toList();
      
      await prefs.setStringList(_storageKey, playlistsJson);
      debugPrint('💾 Saved ${_likedPlaylists.length} liked playlists to storage');
    } catch (e) {
      debugPrint('❌ Error saving liked playlists: $e');
    }
  }

  // Check if a playlist is liked
  static bool isPlaylistLiked(String playlistId) {
    return _likedPlaylists.containsKey(playlistId);
  }

  // Like a trending playlist
  static Future<bool> likeTrendingPlaylist({
    required String playlistId,
    required String title,
    required String channelName,
    required String playlistUrl,
    required String thumbnailUrl,
  }) async {
    try {
      if (_likedPlaylists.containsKey(playlistId)) {
        debugPrint('⚠️ Playlist already liked: $title');
        return false; // Already liked
      }

      final likedPlaylist = LikedPlaylist(
        id: playlistId,
        title: title,
        channelName: channelName,
        playlistUrl: playlistUrl,
        thumbnailUrl: thumbnailUrl,
        likedAt: DateTime.now(),
        source: 'trending',
      );

      _likedPlaylists[playlistId] = likedPlaylist;
      await _saveLikedPlaylists();
      
      debugPrint('❤️ Liked trending playlist: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Error liking playlist: $e');
      return false;
    }
  }

  // Like a user playlist
  static Future<bool> likeUserPlaylist({
    required String playlistId,
    required String title,
    required String channelName,
    required String playlistUrl,
    required String thumbnailUrl,
  }) async {
    try {
      if (_likedPlaylists.containsKey(playlistId)) {
        debugPrint('⚠️ Playlist already liked: $title');
        return false; // Already liked
      }

      final likedPlaylist = LikedPlaylist(
        id: playlistId,
        title: title,
        channelName: channelName,
        playlistUrl: playlistUrl,
        thumbnailUrl: thumbnailUrl,
        likedAt: DateTime.now(),
        source: 'user',
      );

      _likedPlaylists[playlistId] = likedPlaylist;
      await _saveLikedPlaylists();
      
      debugPrint('❤️ Liked user playlist: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Error liking playlist: $e');
      return false;
    }
  }

  // Like a queue playlist (generated from music queue)
  static Future<bool> likeQueuePlaylist({
    required String playlistId,
    required String title,
    required String channelName,
    required String thumbnailUrl,
  }) async {
    try {
      if (_likedPlaylists.containsKey(playlistId)) {
        debugPrint('⚠️ Queue playlist already liked: $title');
        return false; // Already liked
      }

      final likedPlaylist = LikedPlaylist(
        id: playlistId,
        title: title,
        channelName: channelName,
        playlistUrl: '', // No URL for queue playlists
        thumbnailUrl: thumbnailUrl,
        likedAt: DateTime.now(),
        source: 'queue',
      );

      _likedPlaylists[playlistId] = likedPlaylist;
      await _saveLikedPlaylists();
      
      debugPrint('❤️ Liked queue playlist: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Error liking queue playlist: $e');
      return false;
    }
  }

  // Unlike a playlist
  static Future<bool> unlikePlaylist(String playlistId) async {
    try {
      if (!_likedPlaylists.containsKey(playlistId)) {
        debugPrint('⚠️ Playlist not found in liked playlists: $playlistId');
        return false; // Not liked
      }

      final removedPlaylist = _likedPlaylists.remove(playlistId);
      await _saveLikedPlaylists();
      
      debugPrint('💔 Unliked playlist: ${removedPlaylist?.title ?? playlistId}');
      return true;
    } catch (e) {
      debugPrint('❌ Error unliking playlist: $e');
      return false;
    }
  }

  // Toggle like status of a playlist
  static Future<bool> togglePlaylistLike({
    required String playlistId,
    required String title,
    required String channelName,
    required String playlistUrl,
    required String thumbnailUrl,
    String source = 'trending',
  }) async {
    if (isPlaylistLiked(playlistId)) {
      await unlikePlaylist(playlistId);
      return false; // Now unliked
    } else {
      if (source == 'user') {
        await likeUserPlaylist(
          playlistId: playlistId,
          title: title,
          channelName: channelName,
          playlistUrl: playlistUrl,
          thumbnailUrl: thumbnailUrl,
        );
      } else if (source == 'queue') {
        await likeQueuePlaylist(
          playlistId: playlistId,
          title: title,
          channelName: channelName,
          thumbnailUrl: thumbnailUrl,
        );
      } else {
        await likeTrendingPlaylist(
          playlistId: playlistId,
          title: title,
          channelName: channelName,
          playlistUrl: playlistUrl,
          thumbnailUrl: thumbnailUrl,
        );
      }
      return true; // Now liked
    }
  }

  // Get all liked playlists
  static List<LikedPlaylist> getLikedPlaylists() {
    final playlists = _likedPlaylists.values.toList();
    playlists.sort((a, b) => b.likedAt.compareTo(a.likedAt)); // Most recent first
    return playlists;
  }

  // Get liked playlists by source
  static List<LikedPlaylist> getLikedPlaylistsBySource(String source) {
    final playlists = _likedPlaylists.values
        .where((playlist) => playlist.source == source)
        .toList();
    playlists.sort((a, b) => b.likedAt.compareTo(a.likedAt));
    return playlists;
  }

  // Get liked trending playlists
  static List<LikedPlaylist> getLikedTrendingPlaylists() {
    return getLikedPlaylistsBySource('trending');
  }

  // Get liked user playlists
  static List<LikedPlaylist> getLikedUserPlaylists() {
    return getLikedPlaylistsBySource('user');
  }

  // Get liked queue playlists
  static List<LikedPlaylist> getLikedQueuePlaylists() {
    return getLikedPlaylistsBySource('queue');
  }

  // Clear all liked playlists
  static Future<void> clearAllLikedPlaylists() async {
    _likedPlaylists.clear();
    await _saveLikedPlaylists();
    debugPrint('🗑️ Cleared all liked playlists');
  }

  // Get statistics
  static Map<String, int> getStatistics() {
    final trending = getLikedTrendingPlaylists().length;
    final user = getLikedUserPlaylists().length;
    final queue = getLikedQueuePlaylists().length;
    
    return {
      'total': _likedPlaylists.length,
      'trending': trending,
      'user': user,
      'queue': queue,
    };
  }
}
