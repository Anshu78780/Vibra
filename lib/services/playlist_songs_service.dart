import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/music_model.dart';

class PlaylistSongsService {
  static const String _baseUrl = 'https://song-9bg4.onrender.com';
  
  /// Get songs from a specific playlist
  static Future<List<MusicTrack>> getPlaylistSongs(String playlistId, {int limit = 500}) async {
    try {
      final url = '$_baseUrl/playlist/$playlistId?limit=$limit';
      
      debugPrint('🎵 Getting songs for playlist: $playlistId');
      debugPrint('🌐 Request URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('📝 Raw playlist songs response: $responseBody');
        final jsonData = jsonDecode(responseBody);
        
        debugPrint('📋 Parsed JSON structure: ${jsonData.runtimeType}');
        debugPrint('📋 JSON keys: ${jsonData is Map ? jsonData.keys.toList() : 'Not a map'}');
        
        if (jsonData is Map<String, dynamic> && 
            jsonData.containsKey('playlist') &&
            jsonData['playlist'] is Map<String, dynamic>) {
          
          final playlistData = jsonData['playlist'] as Map<String, dynamic>;
          
          if (playlistData.containsKey('songs') && playlistData['songs'] is List) {
            final songsData = playlistData['songs'] as List;
            debugPrint('🎵 Found ${songsData.length} raw songs');
            
            final songs = songsData
                .where((item) => item is Map<String, dynamic>)
                .map((item) {
                  try {
                    final songMap = item as Map<String, dynamic>;
                    debugPrint('🔄 Processing song: ${songMap['title'] ?? 'Unknown'}');
                    
                    // Convert playlist song format to MusicTrack format
                    final track = MusicTrack.fromJson({
                      'id': songMap['id'] ?? '',
                      'title': songMap['title'] ?? '',
                      'artist': songMap['artist'] ?? songMap['uploader'] ?? '',
                      'album': songMap['album'] ?? '',
                      'audio_url': songMap['audio_url'],
                      'availability': songMap['availability'] ?? 'public',
                      'category': 'playlist',
                      'description': songMap['description'] ?? '',
                      'duration': songMap['duration'] ?? 0,
                      'duration_string': songMap['duration_string'] ?? '0:00',
                      'extractor': songMap['extractor'] ?? 'ytmusic',
                      'like_count': songMap['like_count'],
                      'live_status': songMap['live_status'] ?? 'not_live',
                      'poster_image': songMap['poster_image'] ?? songMap['thumbnail'] ?? '',
                      'source': songMap['source'] ?? 'ytmusicapi',
                      'thumbnail': songMap['thumbnail'] ?? songMap['poster_image'] ?? '',
                      'upload_date': songMap['upload_date'],
                      'uploader': songMap['uploader'] ?? songMap['artist'] ?? '',
                      'view_count': songMap['view_count'],
                      'webpage_url': songMap['webpage_url'] ?? 'https://www.youtube.com/watch?v=None',
                    });
                    
                    return track;
                  } catch (e) {
                    debugPrint('❌ Error parsing song item: $e');
                    debugPrint('❌ Item data: $item');
                    return null;
                  }
                })
                .where((track) => track != null)
                .cast<MusicTrack>()
                .toList();
            
            debugPrint('✅ Successfully parsed ${songs.length} songs');
            for (int i = 0; i < songs.length && i < 3; i++) {
              debugPrint('  ${i + 1}. ${songs[i].title} - ${songs[i].artist}');
            }
            return songs;
          } else {
            debugPrint('❌ Invalid response format - missing songs in playlist');
          }
        } else {
          debugPrint('❌ Invalid response format - missing playlist structure');
          debugPrint('❌ Response structure: $jsonData');
        }
      } else {
        debugPrint('❌ Playlist songs API error: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error getting playlist songs: $e');
    }
    
    return [];
  }
}
