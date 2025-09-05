import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class SuggestionService {
  static const String _baseUrl = 'https://suggestqueries.google.com/complete/search';
  
  /// Get search suggestions from Google's YouTube suggest API
  static Future<List<String>> getSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final encodedQuery = Uri.encodeQueryComponent(query.trim());
      final url = '$_baseUrl?client=firefox&ds=yt&q=$encodedQuery';
      
      debugPrint('🔍 Getting suggestions for: $query');
      debugPrint('🌐 Request URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:91.0) Gecko/20100101 Firefox/91.0',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'en-US,en;q=0.5',
          'DNT': '1',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        // Decode bytes as UTF-8 to handle encoding properly
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('📝 Raw response: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}...');
        
        // Parse the JSON response - format: ["query", ["suggestion1", "suggestion2", ...]]
        final jsonData = jsonDecode(responseBody);
        if (jsonData is List && jsonData.length >= 2 && jsonData[1] is List) {
          final suggestions = (jsonData[1] as List)
              .map((item) => item.toString())
              .where((suggestion) => suggestion.isNotEmpty)
              .take(8) // Limit to 8 suggestions
              .toList();
          
          debugPrint('✅ Got ${suggestions.length} suggestions');
          return suggestions;
        }
      } else {
        debugPrint('❌ Suggestion API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting suggestions: $e');
    }
    
    return [];
  }
}
