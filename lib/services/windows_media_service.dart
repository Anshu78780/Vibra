import 'dart:io';
import 'dart:async';
import 'package:smtc_windows/smtc_windows.dart';

class WindowsMediaService {
  static WindowsMediaService? _instance;
  SMTCWindows? _smtc;
  bool _isInitialized = false;
  String? _lastTitle;
  String? _lastArtist;
  bool? _lastPlayingState;
  int? _lastPositionMs;
  int? _lastDurationMs;
  
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
    
    // Only update if metadata actually changed
    if (_lastTitle == title && _lastArtist == artist) {
      return;
    }
    
    try {
      await _smtc!.updateMetadata(
        MusicMetadata(
          title: title,
          artist: artist,
          album: album ?? 'Vibra',
          thumbnail: thumbnail,
        ),
      );
      
      _lastTitle = title;
      _lastArtist = artist;
      
      // Force SMTC to show by setting a valid state
      await _smtc!.setPlaybackStatus(PlaybackStatus.Paused);
      
      print('🪟 Updated Windows SMTC metadata: $title by $artist');
    } catch (e) {
      print('❌ Failed to update Windows SMTC metadata: $e');
      // Try to reinitialize if update fails
      await _reinitialize();
    }
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
    
    // Ensure we have valid duration
    if (durationMs <= 0) {
      durationMs = 1000; // Minimum 1 second to avoid errors
    }
    
    // Ensure position is within bounds
    positionMs = positionMs.clamp(0, durationMs);
    
    try {
      // Always update playback status to ensure consistency
      await _smtc!.setPlaybackStatus(
        isPlaying ? PlaybackStatus.Playing : PlaybackStatus.Paused,
      );
      
      // Update timeline with clamped values
      await _smtc!.updateTimeline(
        PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: durationMs,
          positionMs: positionMs,
          minSeekTimeMs: 0,
          maxSeekTimeMs: durationMs,
        ),
      );
      
      _lastPlayingState = isPlaying;
      _lastPositionMs = positionMs;
      _lastDurationMs = durationMs;
      
      print('🪟 Updated Windows SMTC playback: ${isPlaying ? "Playing" : "Paused"} at ${positionMs}ms/${durationMs}ms');
    } catch (e) {
      print('❌ Failed to update Windows SMTC playback status: $e');
      // Try to reinitialize if update fails
      await _reinitialize();
    }
  }
  
  Future<void> _reinitialize() async {
    print('🔄 Attempting to reinitialize Windows SMTC...');
    _isInitialized = false;
    _lastTitle = null;
    _lastArtist = null;
    _lastPlayingState = null;
    _lastPositionMs = null;
    _lastDurationMs = null;
    
    if (_smtc != null) {
      try {
        await _smtc!.dispose();
      } catch (e) {
        print('⚠️ Error disposing SMTC during reinit: $e');
      }
      _smtc = null;
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    await initialize();
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
