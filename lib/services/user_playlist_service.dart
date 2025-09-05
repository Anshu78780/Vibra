import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/music_model.dart';
import '../services/playlist_songs_service.dart';

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
  static final Map<String, UserPlaylist> _userPlaylists = {};

  // Load cached playlists from SharedPreferences
  static Future<void> loadCachedPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = prefs.getStringList(_storageKey) ?? [];
      
      _userPlaylists.clear();
      for (final playlistJson in playlistsJson) {
        final playlistMap = json.decode(playlistJson);
        final playlist = UserPlaylist.fromJson(playlistMap);
        _userPlaylists[playlist.id] = playlist;
      }
      
      debugPrint('Loaded ${_userPlaylists.length} user playlists from cache');
    } catch (e) {
      debugPrint('Error loading user playlists from cache: $e');
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
  }

  // Get all user playlists
  static List<UserPlaylist> getUserPlaylists() {
    final playlists = _userPlaylists.values.toList();
    playlists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return playlists;
  }

  // Get playlist songs
  static Future<List<MusicTrack>> getPlaylistSongs(String playlistId) async {
    return await PlaylistSongsService.getPlaylistSongs(playlistId);
  }

  // Clear all user playlists
  static Future<void> clearAllPlaylists() async {
    _userPlaylists.clear();
    await _savePlaylistsToCache();
  }
}
