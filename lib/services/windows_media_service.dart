import 'dart:io';
import 'dart:async';
import 'package:smtc_windows/smtc_windows.dart';

class WindowsMediaService {
  static WindowsMediaService? _instance;
  SMTCWindows? _smtc;
  bool _isInitialized = false;
  bool _reinitializing = false;
  String? _lastTitle;
  String? _lastArtist;
  bool? _lastPlayingState;
  int? _lastPositionMs;
  int? _lastDurationMs;
  Duration? _lastPosition;
  Duration? _lastDuration;
  
  static WindowsMediaService get instance {
    _instance ??= WindowsMediaService._();
    return _instance!;
  }
  
  WindowsMediaService._();
  
  bool get isInitialized => _isInitialized;
  
  Future<void> initialize() async {
    if (!Platform.isWindows || _isInitialized) return;
    
    try {
      // Dispose any existing instance first
      if (_smtc != null) {
        await _smtc!.dispose();
        _smtc = null;
      }
      
      _smtc = SMTCWindows(
        metadata: const MusicMetadata(
          title: 'Vibra Music Player',
          artist: 'Ready to play music',
          album: 'Vibra',
        ),
        config: const SMTCConfig(
          fastForwardEnabled: true,
          nextEnabled: true,
          pauseEnabled: true,
          playEnabled: true,
          prevEnabled: true,
          rewindEnabled: true,
          stopEnabled: true,
        ),
      );
      
      // Force enable the SMTC
      await _smtc!.setPlaybackStatus(PlaybackStatus.Stopped);
      await Future.delayed(const Duration(milliseconds: 100));
      
      _isInitialized = true;
      print('✅ Windows SMTC initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Windows SMTC: $e');
      _isInitialized = false;
    }
  }
  
  Future<void> updateMetadata({
    required String title,
    required String artist,
    String? album,
    String? thumbnail,
  }) async {
    if (!Platform.isWindows || _smtc == null || !_isInitialized) {
      print('⚠️ Cannot update metadata: Windows=${Platform.isWindows}, SMTC=${_smtc != null}, Initialized=$_isInitialized');
      return;
    }
    
    // Validate and sanitize input
    final sanitizedTitle = _sanitizeString(title, 'Unknown Track');
    final sanitizedArtist = _sanitizeString(artist, 'Unknown Artist');
    final sanitizedAlbum = _sanitizeString(album ?? 'Vibra', 'Vibra');
    
    // Only update if metadata actually changed
    if (_lastTitle == sanitizedTitle && _lastArtist == sanitizedArtist) {
      return;
    }
    
    try {
      await _smtc!.updateMetadata(
        MusicMetadata(
          title: sanitizedTitle,
          artist: sanitizedArtist,
          album: sanitizedAlbum,
          thumbnail: thumbnail?.isNotEmpty == true ? thumbnail : null,
        ),
      );
      
      _lastTitle = sanitizedTitle;
      _lastArtist = sanitizedArtist;
      
      // Small delay to prevent rapid updates
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Force SMTC to show by setting a valid state
      await _smtc!.setPlaybackStatus(PlaybackStatus.Paused);
      
      print('🪟 Updated Windows SMTC metadata: $sanitizedTitle by $sanitizedArtist');
    } catch (e) {
      print('❌ Failed to update Windows SMTC metadata: $e');
      // Don't try to reinitialize on every error to avoid infinite loops
      if (e.toString().contains('PanicException') || e.toString().contains('InvalidOperation')) {
        print('🔄 Critical SMTC error, scheduling reinitialize...');
        Future.delayed(const Duration(seconds: 1), () => _reinitialize());
      }
    }
  }
  
  // Helper method to sanitize strings for SMTC
  String _sanitizeString(String? input, String fallback) {
    if (input == null || input.trim().isEmpty) {
      return fallback;
    }
    
    // Limit length to prevent SMTC errors (Windows SMTC has limits)
    final sanitized = input.trim();
    if (sanitized.length > 100) {
      return '${sanitized.substring(0, 97)}...';
    }
    
    return sanitized;
  }
  
  Future<void> updatePlaybackStatus({
    required bool isPlaying,
    required int positionMs,
    required int durationMs,
  }) async {
    if (!Platform.isWindows || _smtc == null || !_isInitialized) {
      print('⚠️ Cannot update playback status: Windows=${Platform.isWindows}, SMTC=${_smtc != null}, Initialized=$_isInitialized');
      return;
    }
    
    // Validate and sanitize input values
    var validDurationMs = durationMs;
    var validPositionMs = positionMs;
    
    // Ensure we have valid duration (minimum 1 second, maximum 24 hours)
    if (validDurationMs <= 0) {
      validDurationMs = 3 * 60 * 1000; // Default to 3 minutes
      print('⚠️ Invalid duration $durationMs, using default ${validDurationMs}ms');
    } else if (validDurationMs > 24 * 60 * 60 * 1000) {
      validDurationMs = 24 * 60 * 60 * 1000; // Cap at 24 hours
      print('⚠️ Duration too long $durationMs, capped to ${validDurationMs}ms');
    }
    
    // Ensure position is within bounds
    validPositionMs = validPositionMs.clamp(0, validDurationMs);
    
    // Skip update if values haven't changed significantly (reduce SMTC spam)
    if (_lastPlayingState == isPlaying && 
        _lastPositionMs != null && 
        _lastDurationMs != null &&
        (validPositionMs - _lastPositionMs!).abs() < 2000 && // Less than 2 seconds difference
        validDurationMs == _lastDurationMs) {
      return;
    }
    
    try {
      // Update playback status first (safer)
      await _smtc!.setPlaybackStatus(
        isPlaying ? PlaybackStatus.Playing : PlaybackStatus.Paused,
      );
      
      // Small delay to prevent rapid successive calls
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Update timeline with validated values
      await _smtc!.updateTimeline(
        PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: validDurationMs,
          positionMs: validPositionMs,
          minSeekTimeMs: 0,
          maxSeekTimeMs: validDurationMs,
        ),
      );
      
      _lastPlayingState = isPlaying;
      _lastPositionMs = validPositionMs;
      _lastDurationMs = validDurationMs;
      
      print('🪟 Updated Windows SMTC playback: ${isPlaying ? "Playing" : "Paused"} at ${_formatTime(validPositionMs)}/${_formatTime(validDurationMs)}');
    } catch (e) {
      print('❌ Failed to update Windows SMTC playback status: $e');
      
      // Handle specific error types
      if (e.toString().contains('PanicException')) {
        print('🔄 SMTC Panic detected, scheduling delayed reinitialize...');
        // Don't reinitialize immediately to avoid infinite loops
        Future.delayed(const Duration(seconds: 3), () {
          if (!_isInitialized) {
            _reinitialize();
          }
        });
      } else {
        // For other errors, try a simpler reinitialize
        Future.delayed(const Duration(milliseconds: 500), () => _reinitialize());
      }
    }
  }
  
  // Helper to format time in mm:ss format
  String _formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  Future<void> _reinitialize() async {
    print('🔄 Attempting to reinitialize Windows SMTC...');
    
    // Prevent multiple concurrent reinitializations
    if (_reinitializing) {
      print('🔄 Reinitialize already in progress, skipping...');
      return;
    }
    _reinitializing = true;
    
    try {
      _isInitialized = false;
      _lastTitle = null;
      _lastArtist = null;
      _lastPlayingState = null;
      _lastPositionMs = null;
      _lastDurationMs = null;
      
      // Safely dispose existing instance
      if (_smtc != null) {
        try {
          await _smtc!.dispose();
          print('🗑️ Disposed old SMTC instance');
        } catch (e) {
          print('⚠️ Error disposing SMTC during reinit: $e');
        }
        _smtc = null;
      }
      
      // Wait longer before reinitializing to let Windows clean up
      await Future.delayed(const Duration(seconds: 1));
      
      // Try to reinitialize
      await initialize();
      
      if (_isInitialized) {
        print('✅ SMTC successfully reinitialized');
      } else {
        print('❌ SMTC reinitialize failed');
      }
    } catch (e) {
      print('❌ Error during SMTC reinitialize: $e');
    } finally {
      _reinitializing = false;
    }
  }
  
  Future<void> forceShow() async {
    if (!Platform.isWindows || _smtc == null || !_isInitialized) return;
    
    try {
      // Force the SMTC to appear by setting metadata and status
      await _smtc!.updateMetadata(
        MusicMetadata(
          title: _lastTitle ?? 'Vibra Music Player',
          artist: _lastArtist ?? 'Ready to play music',
          album: 'Vibra',
        ),
      );
      
      await _smtc!.setPlaybackStatus(
        _lastPlayingState == true ? PlaybackStatus.Playing : PlaybackStatus.Paused,
      );
      
      if (_lastDurationMs != null && _lastPositionMs != null) {
        await _smtc!.updateTimeline(
          PlaybackTimeline(
            startTimeMs: 0,
            endTimeMs: _lastDurationMs!,
            positionMs: _lastPositionMs!,
            minSeekTimeMs: 0,
            maxSeekTimeMs: _lastDurationMs!,
          ),
        );
      }
      
      print('🪟 Forced Windows SMTC to show');
    } catch (e) {
      print('❌ Failed to force show Windows SMTC: $e');
    }
  }
  
  Future<void> setButtonPressHandler({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
    required Function() onStop,
    required Function(int positionMs) onSeek,
  }) async {
    if (!Platform.isWindows || _smtc == null) return;
    
    try {
      _smtc!.buttonPressStream.listen((event) {
        print('🪟 Windows SMTC button pressed: $event');
        switch (event) {
          case PressedButton.play:
            onPlay();
            break;
          case PressedButton.pause:
            onPause();
            break;
          case PressedButton.next:
            onNext();
            break;
          case PressedButton.previous:
            onPrevious();
            break;
          case PressedButton.stop:
            onStop();
            break;
          case PressedButton.fastForward:
            // Seek forward 10 seconds
            onSeek(10000);
            break;
          case PressedButton.rewind:
            // Seek backward 10 seconds  
            onSeek(-10000);
            break;
          default:
            // Handle other buttons that we don't use
            print('🪟 Unhandled SMTC button: $event');
            break;
        }
      });
      
      // Remove seekStream listener for now as it might not be available
      
      print('✅ Windows SMTC button handlers set');
    } catch (e) {
      print('❌ Failed to set Windows SMTC button handlers: $e');
    }
  }
  
  Future<void> dispose() async {
    if (!Platform.isWindows || _smtc == null) return;
    
    try {
      await _smtc!.dispose();
      _smtc = null;
      _isInitialized = false;
      print('✅ Windows SMTC disposed');
    } catch (e) {
      print('❌ Failed to dispose Windows SMTC: $e');
    }
  }
}
