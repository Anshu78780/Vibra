import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/music_model.dart';

class RecommendationService {
  static const String _baseUrl = 'https://song-9bg4.onrender.com';
  
  /// Get song recommendations based on a track ID
  static Future<List<MusicTrack>> getRecommendations(String trackId, {int limit = 50}) async {
    if (trackId.trim().isEmpty) return [];
    
    try {
      final url = '$_baseUrl/recommended/$trackId?limit=$limit';
      
      debugPrint('🎵 Getting recommendations for track: $trackId');
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
        debugPrint('📝 Raw recommendation response: $responseBody');
        final jsonData = jsonDecode(responseBody);
        
        debugPrint('📋 Parsed JSON structure: ${jsonData.runtimeType}');
        debugPrint('📋 JSON keys: ${jsonData is Map ? jsonData.keys.toList() : 'Not a map'}');
        
        if (jsonData is Map<String, dynamic> && 
            jsonData.containsKey('recommendations') &&
            jsonData['recommendations'] is Map<String, dynamic> &&
            jsonData['recommendations']['recommendations'] is List) {
          
          final recommendationsData = jsonData['recommendations']['recommendations'] as List;
          debugPrint('🎵 Found ${recommendationsData.length} raw recommendations');
          
          final recommendations = recommendationsData
              .where((item) => item is Map<String, dynamic>)
              .map((item) {
                try {
                  debugPrint('🔄 Processing recommendation item: ${item['title'] ?? 'Unknown'}');
                  return MusicTrack.fromJson(item as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('❌ Error parsing recommendation item: $e');
                  debugPrint('❌ Item data: $item');
                  return null;
                }
              })
              .where((track) => track != null)
              .cast<MusicTrack>()
              .toList();
          
          // Filter out any recommendations that have the same ID as the requested track
          // This helps avoid duplicates when the API returns the same song
          final filteredRecommendations = recommendations.where((rec) {
            if (rec.id == trackId || rec.webpageUrl.contains(trackId)) {
              debugPrint('🚫 Filtering out same track from recommendations: ${rec.title}');
              return false;
            }
            return true;
          }).toList();
          
          debugPrint('✅ Successfully parsed ${recommendations.length} recommendations, filtered to ${filteredRecommendations.length}');
          for (int i = 0; i < filteredRecommendations.length && i < 3; i++) {
            debugPrint('  ${i + 1}. ${filteredRecommendations[i].title} by ${filteredRecommendations[i].artist}');
          }
          return filteredRecommendations;
        } else {
          debugPrint('❌ Invalid response format - missing recommendations structure');
          debugPrint('❌ Response structure: $jsonData');
        }
      } else {
        debugPrint('❌ Recommendation API error: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error getting recommendations: $e');
    }
    
    return [];
  }
  
  /// Get a single recommendation for the next song
  static Future<MusicTrack?> getNextRecommendation(String trackId) async {
    final recommendations = await getRecommendations(trackId, limit: 1);
    return recommendations.isNotEmpty ? recommendations.first : null;
  }
}
