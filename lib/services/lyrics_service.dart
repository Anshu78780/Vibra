import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/lyrics_model.dart';

class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  
  /// Fetch lyrics for a track using search API
  static Future<LyricsData?> getLyrics(String trackName, String artistName, {double? duration}) async {
    try {
      // Clean the track and artist names
      final cleanTrackName = _cleanTrackName(trackName);
      final cleanArtistName = _cleanArtistName(artistName);
      
      print('🎵 Fetching lyrics for: "$cleanTrackName" by "$cleanArtistName"${duration != null ? ' (${duration.toInt()}s)' : ''}');
      
      // First try with both track_name and artist_name parameters
      LyricsData? result = await _searchWithParameters(cleanTrackName, cleanArtistName, duration: duration);
      if (result != null) return result;
      
      // Fallback: try with just track_name
      result = await _searchWithParameters(cleanTrackName, null, duration: duration);
      if (result != null) return result;
      
      // Last attempt: try with alternative cleaning and general search
      final altTrackName = _alternativeClean(trackName);
      final altArtistName = _alternativeClean(artistName);
      result = await _searchWithQuery('$altTrackName $altArtistName', duration: duration);
      
      return result;
    } catch (e) {
      print('❌ Lyrics service error: $e');
      return null;
    }
  }
  
  /// Search lyrics using specific track_name and artist_name parameters
  static Future<LyricsData?> _searchWithParameters(String trackName, String? artistName, {double? duration}) async {
    try {
      final Map<String, String> params = {
        'track_name': trackName,
      };
      
      if (artistName != null && artistName.isNotEmpty) {
        params['artist_name'] = artistName;
      }
      
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final url = '$_baseUrl/search?$queryString';
      print('🌐 Lyrics search URL (parameters): $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Vibra Music App/1.0',
        },
      ).timeout(const Duration(seconds: 10));
      
      return _processSearchResponse(response, duration: duration);
    } catch (e) {
      print('❌ Parameter search error: $e');
      return null;
    }
  }
  
  /// Search lyrics using general q parameter (fallback)
  static Future<LyricsData?> _searchWithQuery(String query, {double? duration}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_baseUrl/search?q=$encodedQuery';
      print('🌐 Lyrics search URL (query): $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Vibra Music App/1.0',
        },
      ).timeout(const Duration(seconds: 10));
      
      return _processSearchResponse(response, duration: duration);
    } catch (e) {
      print('❌ Query search error: $e');
      return null;
    }
  }
  
  /// Process the search response from lrclib API
  static Future<LyricsData?> _processSearchResponse(http.Response response, {double? duration}) async {
    print('🔄 Lyrics API response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final List<dynamic> results = jsonDecode(response.body);
      print('✅ Found ${results.length} search results');
      
      if (results.isNotEmpty) {
        Map<String, dynamic> bestResult = results[0];
        
        // If we have duration, find the best match based on duration and synced lyrics
        if (duration != null) {
          bestResult = _findBestMatchByDuration(results, duration);
          print('🎯 Selected best duration match: "${bestResult['trackName'] ?? bestResult['name']}" by "${bestResult['artistName']}" (${bestResult['duration']}s vs ${duration.toInt()}s)');
        } else {
          // Original logic: prioritize synced lyrics
          for (final result in results) {
            if (result['syncedLyrics'] != null && result['syncedLyrics'].toString().isNotEmpty) {
              bestResult = result;
              break;
            }
          }
          print('✅ Selected result: "${bestResult['trackName'] ?? bestResult['name']}" by "${bestResult['artistName']}"');
        }
        
        return _convertToLyricsData(bestResult);
      } else {
        print('❌ No search results found');
        return null;
      }
    } else {
      print('❌ Lyrics API error: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      return null;
    }
  }
  
  /// Find the best match based on duration and lyrics availability
  static Map<String, dynamic> _findBestMatchByDuration(List<dynamic> results, double targetDuration) {
    final targetDurationInt = targetDuration.toInt();
    
    // Score each result based on duration match and lyrics availability
    Map<String, dynamic> bestResult = results[0];
    double bestScore = -1;
    
    for (final result in results) {
      final resultDuration = result['duration'] ?? 0;
      final hasSyncedLyrics = result['syncedLyrics'] != null && result['syncedLyrics'].toString().isNotEmpty;
      final hasPlainLyrics = result['plainLyrics'] != null && result['plainLyrics'].toString().isNotEmpty;
      
      // Calculate duration difference (smaller is better)
      final durationDiff = (resultDuration - targetDurationInt).abs();
      
      // Calculate score (higher is better)
      double score = 0;
      
      // Perfect duration match gets highest priority
      if (durationDiff == 0) {
        score += 100;
      } else if (durationDiff <= 2) { // Within 2 seconds (as mentioned in API docs)
        score += 80 - (durationDiff * 10); // 80, 70, 60
      } else if (durationDiff <= 5) { // Within 5 seconds
        score += 50 - (durationDiff * 5); // 50, 45, 40, 35, 30
      } else if (durationDiff <= 10) { // Within 10 seconds
        score += 20 - durationDiff; // 20, 19, 18, ..., 10
      } else {
        score += max(0, 10 - (durationDiff / 10)); // Gradually decrease
      }
      
      // Bonus for having synced lyrics
      if (hasSyncedLyrics) {
        score += 30;
      }
      
      // Smaller bonus for having plain lyrics
      if (hasPlainLyrics) {
        score += 10;
      }
      
      print('📊 Result "${result['trackName'] ?? result['name']}" (${resultDuration}s): score = $score (diff: ${durationDiff}s, synced: $hasSyncedLyrics)');
      
      if (score > bestScore) {
        bestScore = score;
        bestResult = result;
      }
    }
    
    return bestResult;
  }
  
  /// Convert lrclib result to our LyricsData format
  static LyricsData _convertToLyricsData(Map<String, dynamic> result) {
    try {
      final syncedLyrics = result['syncedLyrics'] as String?;
      final plainLyrics = result['plainLyrics'] as String?;
      
      List<LyricsLine> lyrics = [];
      String type = 'plain';
      
      if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
        lyrics = _parseSyncedLyrics(syncedLyrics);
        type = 'synced';
      } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
        lyrics = _parsePlainLyrics(plainLyrics);
        type = 'plain';
      }
      
      // Handle duration conversion safely
      int safeDuration = 0;
      final durationValue = result['duration'];
      if (durationValue != null) {
        if (durationValue is int) {
          safeDuration = durationValue;
        } else if (durationValue is double) {
          safeDuration = durationValue.round();
        } else if (durationValue is String) {
          safeDuration = double.tryParse(durationValue)?.round() ?? 0;
        }
      }
      
      // Handle ID conversion safely
      int safeId = 0;
      final idValue = result['id'];
      if (idValue != null) {
        if (idValue is int) {
          safeId = idValue;
        } else if (idValue is double) {
          safeId = idValue.round();
        } else if (idValue is String) {
          safeId = int.tryParse(idValue) ?? 0;
        }
      }
      
      return LyricsData(
        metadata: LyricsMetadata(
          id: safeId,
          name: result['trackName'] ?? result['name'] ?? '',
          trackName: result['trackName'] ?? result['name'] ?? '',
          artistName: result['artistName'] ?? '',
          albumName: result['albumName'] ?? '',
          duration: safeDuration,
          instrumental: result['instrumental'] ?? false,
          plainLyrics: plainLyrics ?? '',
          syncedLyrics: syncedLyrics ?? '',
        ),
        lyrics: lyrics,
        type: type,
      );
    } catch (e) {
      print('❌ Error converting lyrics data: $e');
      print('❌ Result data: $result');
      // Return a minimal valid LyricsData object
      return LyricsData(
        metadata: LyricsMetadata(
          id: 0,
          name: '',
          trackName: '',
          artistName: '',
          albumName: '',
          duration: 0,
          instrumental: false,
          plainLyrics: '',
          syncedLyrics: '',
        ),
        lyrics: [],
        type: 'none',
      );
    }
  }
  
  /// Parse synced lyrics in LRC format
  static List<LyricsLine> _parseSyncedLyrics(String syncedLyrics) {
    final List<LyricsLine> lyrics = [];
    final lines = syncedLyrics.split('\n');
    
    for (final line in lines) {
      final match = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\]\s*(.*)').firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centiseconds = int.parse(match.group(3)!);
        final text = match.group(4)!.trim();
        
        if (text.isNotEmpty) {
          final startTime = minutes * 60 + seconds + (centiseconds / 100);
          lyrics.add(LyricsLine(text: text, startTime: startTime));
        }
      }
    }
    
    return lyrics;
  }
  
  /// Parse plain lyrics (no timing)
  static List<LyricsLine> _parsePlainLyrics(String plainLyrics) {
    final List<LyricsLine> lyrics = [];
    final lines = plainLyrics.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.isNotEmpty) {
        // For plain lyrics, we don't have timing, so use index-based timing
        lyrics.add(LyricsLine(text: text, startTime: i * 3.0)); // 3 seconds per line estimate
      }
    }
    
    return lyrics;
  }
  
  /// Clean track name for better search results
  static String _cleanTrackName(String trackName) {
    return trackName
        .replaceAll(RegExp(r'\([^)]*\)'), '') // Remove content in parentheses
        .replaceAll(RegExp(r'\[[^\]]*\]'), '') // Remove content in brackets
        .replaceAll(RegExp(r'\s*-\s*.*'), '') // Remove everything after dash
        .replaceAll(RegExp(r'\s*\|\s*.*'), '') // Remove everything after pipe
        .replaceAll(RegExp(r'\s+(feat\.?|ft\.?|featuring)\s+.*', caseSensitive: false), '') // Remove featuring
        .replaceAll(RegExp(r'\s*\(.*remix.*\)', caseSensitive: false), '') // Remove remix info
        .replaceAll(RegExp(r'\s*\(.*version.*\)', caseSensitive: false), '') // Remove version info
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }
  
  /// Clean artist name for better search results
  static String _cleanArtistName(String artistName) {
    return artistName
        .replaceAll(RegExp(r'\s*-\s*Topic'), '') // Remove "- Topic" from YouTube
        .replaceAll(RegExp(r'\s*\(.*\)'), '') // Remove content in parentheses
        .replaceAll(RegExp(r'\s*\[.*\]'), '') // Remove content in brackets
        .replaceAll(RegExp(r'\s*(feat\.?|ft\.?|featuring)\s+.*', caseSensitive: false), '') // Remove featuring
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }
  
  /// Alternative cleaning method for fallback searches
  static String _alternativeClean(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Replace special characters with spaces
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }
  
  /// Test method to verify API functionality
  static Future<void> testApi() async {
    print('🧪 Testing lyrics API with known good example...');
    final result = await getLyrics('Señorita', 'Shawn Mendes', duration: 191.0);
    if (result != null) {
      print('✅ API test successful!');
      print('📝 Found lyrics: ${result.type}');
      print('🎵 Track: ${result.metadata.trackName}');
      print('👤 Artist: ${result.metadata.artistName}');
      print('⏱️ Duration: ${result.metadata.duration}s');
      print('📊 Lines count: ${result.lyrics.length}');
      if (result.type == 'synced' && result.lyrics.isNotEmpty) {
        print('🎼 First synced line: "${result.lyrics.first.text}" at ${result.lyrics.first.startTime}s');
      }
    } else {
      print('❌ API test failed - no lyrics found');
    }
  }
  
  /// Debug method to log what track names are being processed
  static void debugTrackInfo(String originalTrack, String originalArtist) {
    print('🔍 DEBUG: Original track info:');
    print('  📀 Track: "$originalTrack"');
    print('  👤 Artist: "$originalArtist"');
    print('🧹 Cleaned track info:');
    print('  📀 Track: "${_cleanTrackName(originalTrack)}"');
    print('  👤 Artist: "${_cleanArtistName(originalArtist)}"');
    print('🔄 Alternative cleaned:');
    print('  📀 Track: "${_alternativeClean(originalTrack)}"');
    print('  👤 Artist: "${_alternativeClean(originalArtist)}"');
  }
}