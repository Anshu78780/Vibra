import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_model.dart';
import 'user_playlist_service.dart';

class LikedSongsService {
  static const String _storageKey = 'liked_songs';
  static final Map<String, MusicTrack> _likedSongs = {};

  // Load cached liked songs from SharedPreferences
  static Future<void> loadCachedLikedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = prefs.getStringList(_storageKey) ?? [];
      
      for (final songJson in songsJson) {
        final songMap = json.decode(songJson);
        final track = MusicTrack.fromJson(songMap);
        _likedSongs[track.webpageUrl] = track;
      }
      
      print('Loaded ${_likedSongs.length} liked songs from cache');
      
      // Also load user playlists
      await UserPlaylistService.loadCachedPlaylists();
    } catch (e) {
      print('Error loading liked songs from cache: $e');
    }
  }

  // Save liked songs to SharedPreferences
  static Future<void> _saveLikedSongsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = _likedSongs.values.map((track) {
        return json.encode(track.toJson());
      }).toList();
      
      await prefs.setStringList(_storageKey, songsJson);
      print('Saved ${_likedSongs.length} liked songs to cache');
    } catch (e) {
      print('Error saving liked songs to cache: $e');
    }
  }

  // Add a song to liked songs
  static Future<void> addLikedSong(MusicTrack track) async {
    _likedSongs[track.webpageUrl] = track;
    await _saveLikedSongsToCache();
  }

  // Remove a song from liked songs
  static Future<void> removeLikedSong(String webpageUrl) async {
    _likedSongs.remove(webpageUrl);
    await _saveLikedSongsToCache();
  }

  // Toggle like status for a song
  static Future<bool> toggleLikedSong(MusicTrack track) async {
    final isLiked = isTrackLiked(track.webpageUrl);
    
    if (isLiked) {
      await removeLikedSong(track.webpageUrl);
      return false;
    } else {
      await addLikedSong(track);
      return true;
    }
  }

  // Check if a song is liked
  static bool isTrackLiked(String webpageUrl) {
    return _likedSongs.containsKey(webpageUrl);
  }

  // Get all liked songs
  static List<MusicTrack> getLikedSongs() {
    return _likedSongs.values.toList();
  }

  // Clear all liked songs
  static Future<void> clearAllLikedSongs() async {
    _likedSongs.clear();
    await _saveLikedSongsToCache();
  }
}
