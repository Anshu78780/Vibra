import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/music_model.dart';

class QueuePlaylist {
  final String id;
  final String name;
  final List<MusicTrack> songs;
  final DateTime createdAt;
  final String? thumbnailUrl;

  QueuePlaylist({
    required this.id,
    required this.name,
    required this.songs,
    required this.createdAt,
    this.thumbnailUrl,
  });

  factory QueuePlaylist.fromJson(Map<String, dynamic> json) {
    return QueuePlaylist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      songs: (json['songs'] as List? ?? [])
          .map((songJson) => MusicTrack.fromJson(songJson))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      thumbnailUrl: json['thumbnailUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songs': songs.map((song) => song.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
    };
  }
}

class QueuePlaylistService {
  static const String _storageKey = 'queue_playlists';
  static final Map<String, QueuePlaylist> _queuePlaylists = {};

  // Load queue playlists from storage
  static Future<void> loadQueuePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = prefs.getStringList(_storageKey) ?? [];
      
      _queuePlaylists.clear();
      for (final playlistJson in playlistsJson) {
        final playlistMap = json.decode(playlistJson);
        final playlist = QueuePlaylist.fromJson(playlistMap);
        _queuePlaylists[playlist.id] = playlist;
      }
      
      debugPrint('🎵 Loaded ${_queuePlaylists.length} queue playlists from storage');
    } catch (e) {
      debugPrint('❌ Error loading queue playlists: $e');
    }
  }

  // Save queue playlists to storage
  static Future<void> _saveQueuePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = _queuePlaylists.values.map((playlist) {
        return json.encode(playlist.toJson());
      }).toList();
      
      await prefs.setStringList(_storageKey, playlistsJson);
      debugPrint('💾 Saved ${_queuePlaylists.length} queue playlists to storage');
    } catch (e) {
      debugPrint('❌ Error saving queue playlists: $e');
    }
  }

  // Save current queue as a playlist
  static Future<String> saveQueueAsPlaylist({
    required String name,
    required List<MusicTrack> songs,
    String? thumbnailUrl,
  }) async {
    try {
      if (songs.isEmpty) {
        throw Exception('Cannot save empty queue as playlist');
      }

      final playlistId = 'queue_${DateTime.now().millisecondsSinceEpoch}';
      
      final queuePlaylist = QueuePlaylist(
        id: playlistId,
        name: name.trim(),
        songs: List.from(songs), // Create a copy of the songs list
        createdAt: DateTime.now(),
        thumbnailUrl: thumbnailUrl,
      );

      _queuePlaylists[playlistId] = queuePlaylist;
      await _saveQueuePlaylists();

      debugPrint('🎵 Saved queue playlist: $name with ${songs.length} songs');
      return playlistId;
    } catch (e) {
      debugPrint('❌ Error saving queue playlist: $e');
      throw e;
    }
  }

  // Get all queue playlists
  static List<QueuePlaylist> getQueuePlaylists() {
    final playlists = _queuePlaylists.values.toList();
    playlists.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
    return playlists;
  }

  // Get a specific queue playlist by ID
  static QueuePlaylist? getQueuePlaylist(String playlistId) {
    return _queuePlaylists[playlistId];
  }

  // Get queue playlist songs
  static List<MusicTrack> getQueuePlaylistSongs(String playlistId) {
    final playlist = _queuePlaylists[playlistId];
    return playlist?.songs ?? [];
  }

  // Delete a queue playlist
  static Future<void> deleteQueuePlaylist(String playlistId) async {
    try {
      final removedPlaylist = _queuePlaylists.remove(playlistId);
      if (removedPlaylist != null) {
        await _saveQueuePlaylists();
        debugPrint('🗑️ Deleted queue playlist: ${removedPlaylist.name}');
      }
    } catch (e) {
      debugPrint('❌ Error deleting queue playlist: $e');
    }
  }

  // Rename a queue playlist
  static Future<void> renameQueuePlaylist(String playlistId, String newName) async {
    try {
      final playlist = _queuePlaylists[playlistId];
      if (playlist != null) {
        final updatedPlaylist = QueuePlaylist(
          id: playlist.id,
          name: newName.trim(),
          songs: playlist.songs,
          createdAt: playlist.createdAt,
          thumbnailUrl: playlist.thumbnailUrl,
        );
        
        _queuePlaylists[playlistId] = updatedPlaylist;
        await _saveQueuePlaylists();
        debugPrint('✏️ Renamed queue playlist to: $newName');
      }
    } catch (e) {
      debugPrint('❌ Error renaming queue playlist: $e');
    }
  }

  // Check if a queue playlist exists
  static bool hasQueuePlaylist(String playlistId) {
    return _queuePlaylists.containsKey(playlistId);
  }

  // Get statistics
  static Map<String, int> getStatistics() {
    final totalSongs = _queuePlaylists.values
        .fold<int>(0, (sum, playlist) => sum + playlist.songs.length);
    
    return {
      'totalPlaylists': _queuePlaylists.length,
      'totalSongs': totalSongs,
    };
  }

  // Clear all queue playlists
  static Future<void> clearAllQueuePlaylists() async {
    try {
      _queuePlaylists.clear();
      await _saveQueuePlaylists();
      debugPrint('🗑️ Cleared all queue playlists');
    } catch (e) {
      debugPrint('❌ Error clearing queue playlists: $e');
    }
  }
}
