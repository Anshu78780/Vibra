import 'dart:async';
import 'package:flutter/material.dart';
import '../models/music_model.dart';
import '../services/audio_service.dart' as yt_audio_service;

class PreloadingService {
  static final Map<String, String> _preloadedUrls = {};
  static final Map<String, Completer<String?>> _preloadingRequests = {};
  
  /// Preload audio URL for a track
  static Future<void> preloadAudioUrl(MusicTrack track) async {
    final trackId = _extractVideoId(track.webpageUrl);
    if (trackId == null || _preloadedUrls.containsKey(trackId)) {
      return; // Already preloaded or invalid URL
    }
    
    // Check if already preloading
    if (_preloadingRequests.containsKey(trackId)) {
      return;
    }
    
    debugPrint('🔄 Preloading audio URL for: ${track.title}');
    
    final completer = Completer<String?>();
    _preloadingRequests[trackId] = completer;
    
    try {
      final audioUrl = await yt_audio_service.AudioService.getAudioUrl(trackId);
      _preloadedUrls[trackId] = audioUrl;
      completer.complete(audioUrl);
      debugPrint('✅ Preloaded audio URL for: ${track.title}');
    } catch (e) {
      debugPrint('❌ Failed to preload audio URL for ${track.title}: $e');
      completer.complete(null);
    } finally {
      _preloadingRequests.remove(trackId);
    }
  }
  
  /// Get preloaded audio URL for a track
  static Future<String?> getPreloadedAudioUrl(MusicTrack track) async {
    final trackId = _extractVideoId(track.webpageUrl);
    if (trackId == null) return null;
    
    // Check if already preloaded
    if (_preloadedUrls.containsKey(trackId)) {
      debugPrint('🎯 Using preloaded audio URL for: ${track.title}');
      return _preloadedUrls[trackId];
    }
    
    // Check if currently preloading
    if (_preloadingRequests.containsKey(trackId)) {
      debugPrint('⏳ Waiting for preloading to complete: ${track.title}');
      return await _preloadingRequests[trackId]!.future;
    }
    
    return null;
  }
  
  /// Clear preloaded URLs to free memory
  static void clearOldPreloads(List<String> currentQueueIds) {
    final keysToRemove = _preloadedUrls.keys
        .where((key) => !currentQueueIds.contains(key))
        .toList();
    
    for (final key in keysToRemove) {
      _preloadedUrls.remove(key);
      debugPrint('🗑️ Cleared preloaded URL for: $key');
    }
  }
  
  /// Extract video ID from YouTube URL
  static String? _extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }
  
  /// Check if an audio URL is preloaded
  static bool isPreloaded(MusicTrack track) {
    final trackId = _extractVideoId(track.webpageUrl);
    return trackId != null && _preloadedUrls.containsKey(trackId);
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'preloaded_count': _preloadedUrls.length,
      'preloading_count': _preloadingRequests.length,
      'preloaded_tracks': _preloadedUrls.keys.toList(),
    };
  }
}
