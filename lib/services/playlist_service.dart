import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/playlist_model.dart';

class PlaylistService {
  static const String _baseUrl = 'https://song-9bg4.onrender.com';
  
  /// Get trending playlists for a specific country
  static Future<List<Playlist>> getTrendingPlaylists({String country = 'IN', int limit = 500}) async {
    try {
      final url = '$_baseUrl/trending/$country?limit=$limit';
      
      debugPrint('🎵 Getting trending playlists for country: $country');
      debugPrint('🌐 Request URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('📝 Raw playlist response: $responseBody');
        final jsonData = jsonDecode(responseBody);
        
        debugPrint('📋 Parsed JSON structure: ${jsonData.runtimeType}');
        debugPrint('📋 JSON keys: ${jsonData is Map ? jsonData.keys.toList() : 'Not a map'}');
        
        if (jsonData is Map<String, dynamic> && 
            jsonData.containsKey('playlists') &&
            jsonData['playlists'] is List) {
          
          final playlistsData = jsonData['playlists'] as List;
          debugPrint('🎵 Found ${playlistsData.length} raw playlists');
          
          final playlists = playlistsData
              .where((item) => item is Map<String, dynamic>)
              .map((item) {
                try {
                  debugPrint('🔄 Processing playlist item: ${item['title'] ?? 'Unknown'}');
                  return Playlist.fromJson(item as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('❌ Error parsing playlist item: $e');
                  debugPrint('❌ Item data: $item');
                  return null;
                }
              })
              .where((playlist) => playlist != null)
              .cast<Playlist>()
              .toList();
          
          debugPrint('✅ Successfully parsed ${playlists.length} playlists');
          for (int i = 0; i < playlists.length && i < 3; i++) {
            debugPrint('  ${i + 1}. ${playlists[i].title} - ${playlists[i].section}');
          }
          return playlists;
        } else {
          debugPrint('❌ Invalid response format - missing playlists structure');
          debugPrint('❌ Response structure: $jsonData');
        }
      } else {
        debugPrint('❌ Playlist API error: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error getting playlists: $e');
    }
    
    return [];
  }
}
