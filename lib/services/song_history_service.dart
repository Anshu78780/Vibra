import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_model.dart';

class SongHistoryService {
  static const String _historyKey = 'song_history';
  static const int _maxHistoryItems = 1000; // Maximum songs to keep in history
  
  static final SongHistoryService _instance = SongHistoryService._internal();
  factory SongHistoryService() => _instance;
  SongHistoryService._internal();

  /// Add a song to the history
  Future<void> addToHistory(MusicTrack track) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> history = await getHistory();
      
      // Create a history entry with timestamp
      final historyEntry = {
        'track': track.toJson(),
        'playedAt': DateTime.now().toIso8601String(),
        'id': '${track.id}_${DateTime.now().millisecondsSinceEpoch}', // Unique ID for each play
      };
      
      // Remove any existing entry with the same track ID to avoid duplicates at the top
      history.removeWhere((entry) => entry['track']['id'] == track.id);
      
      // Add to the beginning of the list (most recent first)
      history.insert(0, historyEntry);
      
      // Keep only the most recent items
      if (history.length > _maxHistoryItems) {
        history = history.take(_maxHistoryItems).toList();
      }
      
      // Save to SharedPreferences
      await prefs.setString(_historyKey, jsonEncode(history));
    } catch (e) {
      print('Error adding song to history: $e');
    }
  }

  /// Get the complete song history
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      
      if (historyJson == null) {
        return [];
      }
      
      final List<dynamic> historyData = jsonDecode(historyJson);
      return historyData.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting song history: $e');
      return [];
    }
  }

  /// Get history as a list of MusicTrack objects with play timestamps
  Future<List<HistoryEntry>> getHistoryEntries() async {
    try {
      final history = await getHistory();
      return history.map((entry) {
        final track = MusicTrack.fromJson(entry['track']);
        final playedAt = DateTime.parse(entry['playedAt']);
        final id = entry['id'] as String;
        return HistoryEntry(track: track, playedAt: playedAt, id: id);
      }).toList();
    } catch (e) {
      print('Error getting history entries: $e');
      return [];
    }
  }

  /// Get recently played songs (last 50)
  Future<List<HistoryEntry>> getRecentlyPlayed({int limit = 50}) async {
    final entries = await getHistoryEntries();
    return entries.take(limit).toList();
  }

  /// Get songs played today
  Future<List<HistoryEntry>> getTodaysHistory() async {
    final entries = await getHistoryEntries();
    final today = DateTime.now();
    
    return entries.where((entry) {
      final playedDate = entry.playedAt;
      return playedDate.year == today.year &&
             playedDate.month == today.month &&
             playedDate.day == today.day;
    }).toList();
  }

  /// Get songs played in the last week
  Future<List<HistoryEntry>> getWeeklyHistory() async {
    final entries = await getHistoryEntries();
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    
    return entries.where((entry) {
      return entry.playedAt.isAfter(oneWeekAgo);
    }).toList();
  }

  // Most Played functionality removed

  /// Search history by track name or artist
  Future<List<HistoryEntry>> searchHistory(String query) async {
    if (query.trim().isEmpty) return [];
    
    final entries = await getHistoryEntries();
    final lowercaseQuery = query.toLowerCase();
    
    return entries.where((entry) {
      final track = entry.track;
      return track.title.toLowerCase().contains(lowercaseQuery) ||
             track.artist.toLowerCase().contains(lowercaseQuery) ||
             track.album.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Clear all history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  /// Remove a specific entry from history
  Future<void> removeFromHistory(String entryId) async {
    try {
      List<Map<String, dynamic>> history = await getHistory();
      history.removeWhere((entry) => entry['id'] == entryId);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(history));
    } catch (e) {
      print('Error removing from history: $e');
    }
  }

  /// Get history statistics
  Future<Map<String, dynamic>> getHistoryStats() async {
    final entries = await getHistoryEntries();
    
    if (entries.isEmpty) {
      return {
        'totalPlays': 0,
        'uniqueSongs': 0,
        'totalListeningTime': 0,
        'averagePerDay': 0.0,
        'firstPlay': null,
        'lastPlay': null,
      };
    }
    
    final uniqueTrackIds = <String>{};
    int totalListeningTime = 0;
    
    for (final entry in entries) {
      uniqueTrackIds.add(entry.track.id);
      totalListeningTime += entry.track.duration;
    }
    
    final firstPlay = entries.last.playedAt;
    final lastPlay = entries.first.playedAt;
    final daysSinceFirst = DateTime.now().difference(firstPlay).inDays + 1;
    final averagePerDay = entries.length / daysSinceFirst;
    
    return {
      'totalPlays': entries.length,
      'uniqueSongs': uniqueTrackIds.length,
      'totalListeningTime': totalListeningTime,
      'averagePerDay': averagePerDay,
      'firstPlay': firstPlay,
      'lastPlay': lastPlay,
    };
  }
}

/// Model class for history entries
class HistoryEntry {
  final MusicTrack track;
  final DateTime playedAt;
  final String id;
  
  HistoryEntry({
    required this.track,
    required this.playedAt,
    required this.id,
  });
}
