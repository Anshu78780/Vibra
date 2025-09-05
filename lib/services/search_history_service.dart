import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _historyKey = 'search_history';
  static const int _maxHistoryItems = 20;

  /// Add a search query to history
  static Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    
    // Remove if already exists to avoid duplicates and move to top
    history.remove(query.trim());
    
    // Add to the beginning of the list
    history.insert(0, query.trim());
    
    // Keep only the most recent items
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    
    // Save to preferences
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  /// Get search history
  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded.cast<String>();
    } catch (e) {
      // If there's an error decoding, return empty list and clear corrupted data
      await clearHistory();
      return [];
    }
  }

  /// Remove a specific search query from history
  static Future<void> removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    
    history.remove(query);
    
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  /// Clear all search history
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  /// Get recent searches with a limit
  static Future<List<String>> getRecentSearches({int limit = 10}) async {
    final history = await getHistory();
    return history.take(limit).toList();
  }

  /// Check if a query exists in history
  static Future<bool> isInHistory(String query) async {
    final history = await getHistory();
    return history.contains(query.trim());
  }
}
