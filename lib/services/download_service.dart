import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/music_model.dart';
import '../services/audio_service.dart' as yt_audio_service;

// Simple semaphore implementation for concurrent downloads
class Semaphore {
  int _count;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this._count);

  Future<void> acquire() async {
    if (_count > 0) {
      _count--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _count++;
    }
  }
}

class BulkDownloadStatus {
  final int totalTracks;
  final int completedTracks;
  final int failedTracks;
  final bool isDownloading;
  final String? currentTrackTitle;
  final List<String> failedTrackTitles;

  BulkDownloadStatus({
    required this.totalTracks,
    required this.completedTracks,
    required this.failedTracks,
    required this.isDownloading,
    this.currentTrackTitle,
    this.failedTrackTitles = const [],
  });

  double get progress => totalTracks > 0 ? completedTracks / totalTracks : 0.0;
  int get remainingTracks => totalTracks - completedTracks - failedTracks;
}

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, double>> _progressController = StreamController<Map<String, double>>.broadcast();
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _activeDownloads = {};
  
  // Bulk download state
  final StreamController<BulkDownloadStatus> _bulkDownloadController = StreamController<BulkDownloadStatus>.broadcast();
  bool _isBulkDownloading = false;
  bool _shouldCancelDownloads = false;
  int _bulkTotalTracks = 0;
  int _bulkCompletedTracks = 0;
  int _bulkFailedTracks = 0;

  Stream<Map<String, double>> get downloadProgressStream => _progressController.stream;
  Stream<Map<String, double>> get progressStream => _progressController.stream;
  Stream<BulkDownloadStatus> get bulkDownloadStream => _bulkDownloadController.stream;

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
    if (Platform.isAndroid) {
      // Request storage permissions for Android
      await _requestStoragePermissions();
      
      try {
        // Try to get external storage directory first (Downloads/Vibra)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Create Downloads/Vibra directory
          final vibrasDir = Directory('/storage/emulated/0/Download/Vibra');
          if (!await vibrasDir.exists()) {
            await vibrasDir.create(recursive: true);
          }
          return vibrasDir.path;
        }
      } catch (e) {
        print('❌ Could not access external Downloads directory: $e');
      }
      
      // Fallback to app-specific external directory
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final downloadsDir = Directory('${externalDir.path}/Downloads');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          return downloadsDir.path;
        }
      } catch (e) {
        print('❌ Could not access app external directory: $e');
      }
    }
    
    // Fallback for iOS or if Android external access fails
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/music_downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir.path;
  }

  /// Get downloads directory without requesting permissions
  /// This allows checking existing downloads without permission prompts
  Future<String> _getDownloadsDirectoryWithoutPermissions() async {
    if (Platform.isAndroid) {
      try {
        // Try to get external storage directory first (Downloads/Vibra)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Check if Downloads/Vibra directory exists
          final vibrasDir = Directory('/storage/emulated/0/Download/Vibra');
          if (await vibrasDir.exists()) {
            return vibrasDir.path;
          }
        }
      } catch (e) {
        print('❌ Could not access external Downloads directory without permissions: $e');
      }
      
      // Fallback to app-specific external directory
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final downloadsDir = Directory('${externalDir.path}/Downloads');
          if (await downloadsDir.exists()) {
            return downloadsDir.path;
          }
        }
      } catch (e) {
        print('❌ Could not access app external directory without permissions: $e');
      }
    }
    
    // Fallback for iOS or if Android external access fails
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/music_downloads');
    return downloadsDir.path;
  }

  /// Request storage permissions for Android
  Future<bool> _requestStoragePermissions() async {
    if (!Platform.isAndroid) return true;
    
    try {
      // For Android 11+ (API 30+), we need to handle scoped storage
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      
      // Request MANAGE_EXTERNAL_STORAGE permission for Android 11+
      var status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        return true;
      }
      
      // Fallback to regular storage permissions for older Android versions
      var storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) {
        return true;
      }
      
      storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    } catch (e) {
      print('❌ Error requesting storage permissions: $e');
      return false;
    }
  }

  /// Check if storage permissions are granted
  Future<bool> hasStoragePermissions() async {
    if (!Platform.isAndroid) return true;
    
    try {
      // Check for MANAGE_EXTERNAL_STORAGE (Android 11+)
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      
      // Check for regular storage permission
      return await Permission.storage.isGranted;
    } catch (e) {
      print('❌ Error checking storage permissions: $e');
      return false;
    }
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
    // Handle local files (manually placed files)
    if (track.webpageUrl.startsWith('file://')) {
      final filePath = track.webpageUrl.substring(7); // Remove 'file://' prefix
      final file = File(filePath);
      return await file.exists();
    }
    
    // Handle app-downloaded files
    final videoId = _extractVideoId(track.webpageUrl);
    try {
      final downloadsDir = await _getDownloadsDirectoryWithoutPermissions();
      final file = File('$downloadsDir/$videoId.mp3');
      return await file.exists();
    } catch (e) {
      print('❌ Could not check if track is downloaded without permissions: $e');
      return false;
    }
  }

  bool isDownloading(MusicTrack track) {
    final videoId = _extractVideoId(track.webpageUrl);
    return _activeDownloads[videoId] == true;
  }

  double getDownloadProgress(MusicTrack track) {
    final videoId = _extractVideoId(track.webpageUrl);
    return _downloadProgress[videoId] ?? 0.0;
  }

  void stopAllDownloads() {
    debugPrint('🛑 stopAllDownloads() called - setting cancel flag');
    _shouldCancelDownloads = true;
    _activeDownloads.clear();
    _downloadProgress.clear();
    _progressController.add({});
    
    if (_isBulkDownloading) {
      debugPrint('🛑 Stopping bulk download operation');
      _isBulkDownloading = false;
      _bulkDownloadController.add(BulkDownloadStatus(
        totalTracks: _bulkTotalTracks,
        completedTracks: _bulkCompletedTracks,
        failedTracks: _bulkFailedTracks,
        isDownloading: false,
        currentTrackTitle: null,
      ));
    }
    
    debugPrint('🛑 All downloads should now be stopped');
  }

  bool get isAnyDownloadActive => _activeDownloads.isNotEmpty || _isBulkDownloading;

  Future<void> downloadTrack(MusicTrack track, {bool refreshUrl = false}) async {
    final videoId = _extractVideoId(track.webpageUrl);
    if (videoId.isEmpty) {
      throw Exception('Invalid YouTube URL');
    }

    // Check storage permissions on Android
    if (Platform.isAndroid && !(await hasStoragePermissions())) {
      final granted = await _requestStoragePermissions();
      if (!granted) {
        throw Exception('Storage permission required to download music. Please grant permission in Settings.');
      }
    }

    // Only reset cancel flag when starting individual download (not part of bulk)
    if (!_isBulkDownloading) {
      _shouldCancelDownloads = false;
    }

    // Check if downloads should be cancelled
    if (_shouldCancelDownloads) {
      throw Exception('Download cancelled');
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

    // Check if downloads should be cancelled
    if (_shouldCancelDownloads) {
      _activeDownloads.remove(videoId);
      _downloadProgress.remove(videoId);
      _progressController.add(_downloadProgress);
      return;
    }

    try {
      debugPrint('🔽 Starting download for: ${track.title}');
      
      // Show initial notification
      await _showDownloadNotification(
        videoId.hashCode,
        track.title,
        'Starting download...',
        0,
      );

      // Get fresh audio URL to avoid stale URLs
      String audioUrl;
      try {
        audioUrl = await yt_audio_service.AudioService.getAudioUrl(videoId);
        debugPrint('🔗 Got fresh audio URL for: ${track.title}');
      } catch (e) {
        debugPrint('❌ Failed to get fresh URL: $e');
        // If refreshUrl is true and we fail, throw the error
        if (refreshUrl) {
          throw Exception('Failed to get fresh audio URL: $e');
        }
        // Otherwise, try with a different approach or rethrow
        rethrow;
      }
      
      // Check if downloads should be cancelled before making HTTP request
      if (_shouldCancelDownloads) {
        _activeDownloads.remove(videoId);
        _downloadProgress.remove(videoId);
        _progressController.add(_downloadProgress);
        throw Exception('Download cancelled');
      }
      
      // Use HTTP client with better configuration for faster downloads
      final client = http.Client();
      
      try {
        // Start HTTP download with progress tracking
        final request = http.Request('GET', Uri.parse(audioUrl));
        // Add headers that might help with speed
        request.headers.addAll({
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': '*/*',
          'Accept-Encoding': 'identity', // Disable compression for faster transfer
          'Connection': 'keep-alive',
        });
        
        final response = await client.send(request);
        
        if (response.statusCode != 200) {
          throw Exception('Failed to download: ${response.statusCode}');
        }

        final downloadsDir = await _getDownloadsDirectory();
        final file = File('$downloadsDir/$videoId.mp3');
        final sink = file.openWrite();

        final contentLength = response.contentLength ?? 0;
        int downloadedBytes = 0;
        DateTime lastUpdateTime = DateTime.now();
        
        // Use larger buffer for faster downloads
        final chunks = <List<int>>[];
        const bufferSize = 64 * 1024; // 64KB buffer
        
        await for (final chunk in response.stream) {
          chunks.add(chunk);
          downloadedBytes += chunk.length;
          
          // Write in larger batches for better performance
          if (chunks.length >= 10 || downloadedBytes >= bufferSize) {
            for (final bufferedChunk in chunks) {
              sink.add(bufferedChunk);
            }
            chunks.clear();
          }
          
          final progress = contentLength > 0 ? downloadedBytes / contentLength : 0.0;
          _downloadProgress[videoId] = progress;
          
          // Check if downloads should be cancelled
          if (_shouldCancelDownloads) {
            await sink.close();
            await file.delete();
            _activeDownloads.remove(videoId);
            _downloadProgress.remove(videoId);
            _progressController.add(_downloadProgress);
            throw Exception('Download cancelled');
          }
          
          // Update progress every 200ms for more responsive UI
          final now = DateTime.now();
          if (now.difference(lastUpdateTime).inMilliseconds > 200) {
            _progressController.add(_downloadProgress);
            
            // Update notification
            final percentage = (progress * 100).toInt();
            final downloadedMB = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
            final totalMB = contentLength > 0 ? (contentLength / 1024 / 1024).toStringAsFixed(1) : '?';
            
            await _showDownloadNotification(
              videoId.hashCode,
              track.title,
              '$downloadedMB MB / $totalMB MB',
              percentage,
            );
            
            lastUpdateTime = now;
          }
        }
        
        // Write any remaining chunks
        for (final bufferedChunk in chunks) {
          sink.add(bufferedChunk);
        }
        
        await sink.close();
      } finally {
        client.close();
      }

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

  // New bulk download method with concurrent downloads
  Future<void> downloadAllTracks(List<MusicTrack> tracks, {int maxConcurrent = 3}) async {
    if (tracks.isEmpty || _isBulkDownloading) return;
    
    // Check storage permissions on Android before starting bulk download
    if (Platform.isAndroid && !(await hasStoragePermissions())) {
      final granted = await _requestStoragePermissions();
      if (!granted) {
        throw Exception('Storage permission required to download music. Please grant permission in Settings.');
      }
    }
    
    // Reset cancel flag when starting new downloads
    _shouldCancelDownloads = false;
    
    _isBulkDownloading = true;
    _bulkTotalTracks = tracks.length;
    _bulkCompletedTracks = 0;
    _bulkFailedTracks = 0;
    final failedTrackTitles = <String>[];
    
    // Filter out already downloaded tracks
    final tracksToDownload = <MusicTrack>[];
    for (final track in tracks) {
      if (!await isDownloaded(track)) {
        tracksToDownload.add(track);
      } else {
        _bulkCompletedTracks++;
      }
    }
    
    // Update initial status
    _bulkDownloadController.add(BulkDownloadStatus(
      totalTracks: _bulkTotalTracks,
      completedTracks: _bulkCompletedTracks,
      failedTracks: _bulkFailedTracks,
      isDownloading: true,
      failedTrackTitles: failedTrackTitles,
    ));
    
    if (tracksToDownload.isEmpty) {
      _isBulkDownloading = false;
      _bulkDownloadController.add(BulkDownloadStatus(
        totalTracks: _bulkTotalTracks,
        completedTracks: _bulkCompletedTracks,
        failedTracks: _bulkFailedTracks,
        isDownloading: false,
        failedTrackTitles: failedTrackTitles,
      ));
      return;
    }
    
    debugPrint('🔽 Starting bulk download of ${tracksToDownload.length} tracks');
    
    // Process downloads in concurrent batches
    final semaphore = Semaphore(maxConcurrent);
    final futures = tracksToDownload.map((track) async {
      await semaphore.acquire();
      try {
        // Check if downloads should be cancelled before starting each track
        if (_shouldCancelDownloads) {
          semaphore.release();
          return;
        }
        
        _bulkDownloadController.add(BulkDownloadStatus(
          totalTracks: _bulkTotalTracks,
          completedTracks: _bulkCompletedTracks,
          failedTracks: _bulkFailedTracks,
          isDownloading: true,
          currentTrackTitle: track.title,
          failedTrackTitles: failedTrackTitles,
        ));
        
        await downloadTrack(track, refreshUrl: true);
        _bulkCompletedTracks++;
        debugPrint('✅ Bulk download completed: ${track.title} (${_bulkCompletedTracks}/${_bulkTotalTracks})');
      } catch (e) {
        // Check if error is due to cancellation
        if (e.toString().contains('cancelled')) {
          debugPrint('🛑 Download cancelled: ${track.title}');
        } else {
          _bulkFailedTracks++;
          failedTrackTitles.add(track.title);
          debugPrint('❌ Bulk download failed: ${track.title} - $e');
        }
        
        // Try once more with a delay for failed downloads
        try {
          await Future.delayed(const Duration(seconds: 2));
          await downloadTrack(track, refreshUrl: true);
          _bulkCompletedTracks++;
          failedTrackTitles.removeLast(); // Remove from failed list
          _bulkFailedTracks--;
          debugPrint('✅ Retry successful: ${track.title}');
        } catch (retryError) {
          debugPrint('❌ Retry also failed: ${track.title} - $retryError');
        }
      } finally {
        semaphore.release();
        
        // Update status
        _bulkDownloadController.add(BulkDownloadStatus(
          totalTracks: _bulkTotalTracks,
          completedTracks: _bulkCompletedTracks,
          failedTracks: _bulkFailedTracks,
          isDownloading: _bulkCompletedTracks + _bulkFailedTracks < _bulkTotalTracks,
          failedTrackTitles: failedTrackTitles,
        ));
      }
    }).toList();
    
    // Wait for all downloads to complete or until cancelled
    try {
      await Future.wait(futures);
    } catch (e) {
      // If any download fails due to cancellation, stop the bulk operation
      if (e.toString().contains('cancelled') || _shouldCancelDownloads) {
        debugPrint('🛑 Bulk download cancelled');
      }
    }
    
    _isBulkDownloading = false;
    
    // Final status update
    _bulkDownloadController.add(BulkDownloadStatus(
      totalTracks: _bulkTotalTracks,
      completedTracks: _bulkCompletedTracks,
      failedTracks: _bulkFailedTracks,
      isDownloading: false,
      failedTrackTitles: failedTrackTitles,
    ));
    
    debugPrint('🎯 Bulk download finished: ${_bulkCompletedTracks} completed, ${_bulkFailedTracks} failed');
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

  /// Get downloaded tracks without requesting permissions
  /// This allows viewing existing downloads without permission prompts
  /// Also scans for any audio files manually placed in Downloads/Vibra/
  Future<List<MusicTrack>> getDownloadedTracksWithoutPermissionCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final tracksJson = prefs.getString('downloaded_tracks');
    
    // Get app-downloaded tracks
    final appDownloadedTracks = <MusicTrack>[];
    if (tracksJson != null) {
      final List<dynamic> tracksList = jsonDecode(tracksJson);
      appDownloadedTracks.addAll(tracksList.map((json) => MusicTrack.fromJson(json)));
    }
    
    // Get all tracks (app-downloaded + manually placed files)
    final allTracks = <MusicTrack>[];
    final knownVideoIds = <String>{};
    
    try {
      final downloadsDir = await _getDownloadsDirectoryWithoutPermissions();
      final dir = Directory(downloadsDir);
      
      if (await dir.exists()) {
        // First, add valid app-downloaded tracks
        for (final track in appDownloadedTracks) {
          final videoId = _extractVideoId(track.webpageUrl);
          final file = File('$downloadsDir/$videoId.mp3');
          if (await file.exists()) {
            allTracks.add(track);
            knownVideoIds.add(videoId);
          }
        }
        
        // Then scan for additional audio files not tracked by the app
        final audioFiles = await dir.list()
            .where((entity) => entity is File)
            .cast<File>()
            .where((file) => file.path.toLowerCase().endsWith('.mp3') || 
                           file.path.toLowerCase().endsWith('.m4a') ||
                           file.path.toLowerCase().endsWith('.aac') ||
                           file.path.toLowerCase().endsWith('.wav') ||
                           file.path.toLowerCase().endsWith('.flac'))
            .toList();
        
        for (final audioFile in audioFiles) {
          final fileName = audioFile.path.split(Platform.pathSeparator).last;
          final fileNameWithoutExtension = fileName.substring(0, fileName.lastIndexOf('.'));
          
          // Skip if this file is already tracked by the app
          if (knownVideoIds.contains(fileNameWithoutExtension)) {
            continue;
          }
          
          // Create a MusicTrack for manually placed files
          final manualTrack = MusicTrack(
            id: 'manual_$fileNameWithoutExtension',
            title: _formatTrackTitle(fileNameWithoutExtension),
            artist: 'Unknown Artist',
            album: 'Local Files',
            duration: 0, // We'll try to get duration later
            durationString: '00:00',
            thumbnail: '', // No thumbnail for manual files
            posterImage: '',
            webpageUrl: 'file://${audioFile.path}', // Use file path as identifier
            source: 'local',
            availability: 'public',
            category: 'Music',
            description: 'Manually added audio file',
            extractor: 'local',
            liveStatus: 'not_live',
            uploader: 'Local Files',
          );
          
          allTracks.add(manualTrack);
        }
        
        // Update the stored list to include only valid app-downloaded tracks
        final validAppTracks = allTracks.where((track) => 
            track.source != 'local' && appDownloadedTracks.any((appTrack) => 
                appTrack.webpageUrl == track.webpageUrl)).toList();
                
        if (validAppTracks.length != appDownloadedTracks.length) {
          final validTracksJson = validAppTracks.map((t) => t.toJson()).toList();
          await prefs.setString('downloaded_tracks', jsonEncode(validTracksJson));
        }
      }
    } catch (e) {
      print('❌ Could not access downloads directory without permissions: $e');
      // Return the stored tracks without verification if we can't access the directory
      return appDownloadedTracks;
    }
    
    return allTracks;
  }
  
  /// Format filename to a more readable track title
  String _formatTrackTitle(String filename) {
    // Remove common YouTube ID patterns and clean up the filename
    String title = filename;
    
    // Remove YouTube video ID patterns (11 characters alphanumeric)
    title = title.replaceAll(RegExp(r'^[a-zA-Z0-9_-]{11}$'), '');
    
    // Replace underscores and dashes with spaces
    title = title.replaceAll(RegExp(r'[_-]+'), ' ');
    
    // Clean up multiple spaces
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Capitalize first letter of each word
    if (title.isNotEmpty) {
      title = title.split(' ').map((word) {
        if (word.isNotEmpty) {
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }
        return word;
      }).join(' ');
    }
    
    // If title is empty or too short, use the original filename
    if (title.isEmpty || title.length < 3) {
      title = filename;
    }
    
    return title;
  }

  Future<String?> getDownloadedAudioPath(MusicTrack track) async {
    // Handle local files (manually placed files)
    if (track.webpageUrl.startsWith('file://')) {
      final filePath = track.webpageUrl.substring(7); // Remove 'file://' prefix
      final file = File(filePath);
      if (await file.exists()) {
        return file.path;
      }
      return null;
    }
    
    // Handle app-downloaded files
    final videoId = _extractVideoId(track.webpageUrl);
    try {
      final downloadsDir = await _getDownloadsDirectoryWithoutPermissions();
      final file = File('$downloadsDir/$videoId.mp3');
      
      if (await file.exists()) {
        return file.path;
      }
    } catch (e) {
      print('❌ Could not check downloaded audio path without permissions: $e');
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
    _bulkDownloadController.close();
  }
}
