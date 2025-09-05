import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/music_model.dart';
import '../services/audio_service.dart' as yt_audio_service;

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, double>> _progressController = StreamController<Map<String, double>>.broadcast();
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _activeDownloads = {};

  Stream<Map<String, double>> get downloadProgressStream => _progressController.stream;

  Future<void> initialize() async {
    await _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
    
    // Create notification channel for downloads
    const androidChannel = AndroidNotificationChannel(
      'downloads',
      'Downloads',
      description: 'Shows download progress for music files',
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
    );

    await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<String> _getDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/music_downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir.path;
  }

  String _extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1) ?? '';
  }

  Future<bool> isDownloaded(MusicTrack track) async {
    final videoId = _extractVideoId(track.webpageUrl);
    final downloadsDir = await _getDownloadsDirectory();
    final file = File('$downloadsDir/$videoId.mp3');
    return await file.exists();
  }

  Future<void> downloadTrack(MusicTrack track) async {
    final videoId = _extractVideoId(track.webpageUrl);
    if (videoId.isEmpty) {
      throw Exception('Invalid YouTube URL');
    }

    // Check if already downloading
    if (_activeDownloads[videoId] == true) {
      return;
    }

    // Check if already downloaded
    if (await isDownloaded(track)) {
      throw Exception('Track already downloaded');
    }

    _activeDownloads[videoId] = true;
    _downloadProgress[videoId] = 0.0;
    _progressController.add(_downloadProgress);

    try {
      debugPrint('🔽 Starting download for: ${track.title}');
      
      // Show initial notification
      await _showDownloadNotification(
        videoId.hashCode,
        track.title,
        'Starting download...',
        0,
      );

      // Get audio URL
      final audioUrl = await yt_audio_service.AudioService.getAudioUrl(videoId);
      
      // Start HTTP download with progress tracking
      final request = http.Request('GET', Uri.parse(audioUrl));
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final downloadsDir = await _getDownloadsDirectory();
      final file = File('$downloadsDir/$videoId.mp3');
      final sink = file.openWrite();

      final contentLength = response.contentLength ?? 0;
      int downloadedBytes = 0;
      DateTime lastUpdateTime = DateTime.now();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        
        final progress = contentLength > 0 ? downloadedBytes / contentLength : 0.0;
        _downloadProgress[videoId] = progress;
        
        // Update progress every 500ms to avoid too frequent updates
        final now = DateTime.now();
        if (now.difference(lastUpdateTime).inMilliseconds > 500) {
          _progressController.add(_downloadProgress);
          
          // Update notification
          final percentage = (progress * 100).toInt();
          final downloadedMB = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
          final totalMB = contentLength > 0 ? (contentLength / 1024 / 1024).toStringAsFixed(1) : '?';
          
          await _showDownloadNotification(
            videoId.hashCode,
            track.title,
            'Downloaded $downloadedMB MB / $totalMB MB',
            percentage,
          );
          
          lastUpdateTime = now;
        }
      }

      await sink.close();

      // Save track metadata
      await _saveTrackMetadata(track);
      
      // Update progress to complete
      _downloadProgress[videoId] = 1.0;
      _progressController.add(_downloadProgress);
      
      // Show completion notification
      await _showDownloadCompleteNotification(
        videoId.hashCode,
        track.title,
      );
      
      debugPrint('✅ Download completed: ${track.title}');
      
    } catch (e) {
      debugPrint('❌ Download failed for ${track.title}: $e');
      
      // Clean up partial download
      final downloadsDir = await _getDownloadsDirectory();
      final file = File('$downloadsDir/$videoId.mp3');
      if (await file.exists()) {
        await file.delete();
      }
      
      // Show error notification
      await _showDownloadErrorNotification(
        videoId.hashCode,
        track.title,
        e.toString(),
      );
      
      rethrow;
    } finally {
      _activeDownloads.remove(videoId);
      
      // Remove from progress after a delay to show completion
      Timer(const Duration(seconds: 2), () {
        _downloadProgress.remove(videoId);
        _progressController.add(_downloadProgress);
      });
    }
  }

  Future<void> _saveTrackMetadata(MusicTrack track) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedTracks = await getDownloadedTracks();
    
    // Add track if not already in list
    final exists = downloadedTracks.any((t) => t.webpageUrl == track.webpageUrl);
    if (!exists) {
      downloadedTracks.add(track);
      final tracksJson = downloadedTracks.map((t) => t.toJson()).toList();
      await prefs.setString('downloaded_tracks', jsonEncode(tracksJson));
    }
  }

  Future<List<MusicTrack>> getDownloadedTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final tracksJson = prefs.getString('downloaded_tracks');
    
    if (tracksJson == null) return [];
    
    final List<dynamic> tracksList = jsonDecode(tracksJson);
    final tracks = tracksList.map((json) => MusicTrack.fromJson(json)).toList();
    
    // Filter out tracks whose files no longer exist
    final validTracks = <MusicTrack>[];
    final downloadsDir = await _getDownloadsDirectory();
    
    for (final track in tracks) {
      final videoId = _extractVideoId(track.webpageUrl);
      final file = File('$downloadsDir/$videoId.mp3');
      if (await file.exists()) {
        validTracks.add(track);
      }
    }
    
    // Update the stored list if any tracks were removed
    if (validTracks.length != tracks.length) {
      final validTracksJson = validTracks.map((t) => t.toJson()).toList();
      await prefs.setString('downloaded_tracks', jsonEncode(validTracksJson));
    }
    
    return validTracks;
  }

  Future<String?> getDownloadedAudioPath(MusicTrack track) async {
    final videoId = _extractVideoId(track.webpageUrl);
    final downloadsDir = await _getDownloadsDirectory();
    final file = File('$downloadsDir/$videoId.mp3');
    
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  Future<void> deleteDownload(MusicTrack track) async {
    final videoId = _extractVideoId(track.webpageUrl);
    final downloadsDir = await _getDownloadsDirectory();
    final file = File('$downloadsDir/$videoId.mp3');
    
    if (await file.exists()) {
      await file.delete();
    }
    
    // Remove from metadata
    final prefs = await SharedPreferences.getInstance();
    final downloadedTracks = await getDownloadedTracks();
    downloadedTracks.removeWhere((t) => t.webpageUrl == track.webpageUrl);
    
    final tracksJson = downloadedTracks.map((t) => t.toJson()).toList();
    await prefs.setString('downloaded_tracks', jsonEncode(tracksJson));
  }

  Future<void> clearAllDownloads() async {
    final downloadsDir = await _getDownloadsDirectory();
    final dir = Directory(downloadsDir);
    
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create();
    }
    
    // Clear metadata
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('downloaded_tracks');
  }

  Future<void> _showDownloadNotification(
    int id,
    String title,
    String body,
    int progress,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Shows download progress for music files',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: progress < 100,
      autoCancel: false,
      silent: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      id,
      'Downloading: $title',
      body,
      notificationDetails,
    );
  }

  Future<void> _showDownloadCompleteNotification(int id, String title) async {
    const androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Shows download progress for music files',
      importance: Importance.low,
      priority: Priority.low,
      autoCancel: true,
      silent: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      id,
      'Download Complete',
      '$title has been downloaded',
      notificationDetails,
    );
  }

  Future<void> _showDownloadErrorNotification(int id, String title, String error) async {
    const androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Shows download progress for music files',
      importance: Importance.low,
      priority: Priority.low,
      autoCancel: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      id,
      'Download Failed',
      'Failed to download $title',
      notificationDetails,
    );
  }

  void dispose() {
    _progressController.close();
  }
}
