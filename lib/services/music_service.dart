import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/music_model.dart';

class MusicService {
  static const String baseUrl = 'https://song-9bg4.onrender.com';

  static Future<MusicApiResponse> fetchTrendingMusic({int limit = 200}) async {
    try {
      final uri = Uri.parse('$baseUrl/homepage?limit=$limit');
      print('Fetching data from: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Flutter Music App',
        },
      ).timeout(const Duration(seconds: 30));

      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      
      if (response.statusCode == 200) {
        final responseBody = response.body;
        print('Response body length: ${responseBody.length}');
        
        if (responseBody.isEmpty) {
          throw Exception('Empty response body');
        }
        
        final jsonData = json.decode(responseBody);
        print('JSON decoded successfully');
        
        return MusicApiResponse.fromJson(jsonData);
      } else {
        print('Response body: ${response.body}');
        throw Exception('Failed to load music data: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error in fetchTrendingMusic: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timeout. Please check your internet connection.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection.');
      } else if (e.toString().contains('FormatException')) {
        throw Exception('Invalid response format from server.');
      } else {
        throw Exception('Error fetching music data: $e');
      }
    }
  }

  static Future<SearchResponse> searchMusic(String query, {int limit = 20}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final uri = Uri.parse('$baseUrl/search?q=$encodedQuery&limit=$limit');
      print('Searching for: $query at $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Flutter Music App',
        },
      ).timeout(const Duration(seconds: 30));

      print('Search response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = response.body;
        print('Search response body length: ${responseBody.length}');
        
        if (responseBody.isEmpty) {
          throw Exception('Empty response body');
        }
        
        final jsonData = json.decode(responseBody);
        print('Search JSON decoded successfully');
        
        return SearchResponse.fromJson(jsonData);
      } else {
        print('Search response body: ${response.body}');
        throw Exception('Failed to search music: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error in searchMusic: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Search timeout. Please check your internet connection.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection.');
      } else if (e.toString().contains('FormatException')) {
        throw Exception('Invalid search response format from server.');
      } else {
        throw Exception('Error searching music: $e');
      }
    }
  }
}
