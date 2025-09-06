import 'dart:io';
import 'package:smtc_windows/smtc_windows.dart';

class WindowsMediaService {
  static WindowsMediaService? _instance;
  SMTCWindows? _smtc;
  bool _isInitialized = false;
  
  static WindowsMediaService get instance {
    _instance ??= WindowsMediaService._();
    return _instance!;
  }
  
  WindowsMediaService._();
  
  Future<void> initialize() async {
    if (!Platform.isWindows || _isInitialized) return;
    
    try {
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
      
      _isInitialized = true;
      print('✅ Windows SMTC initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Windows SMTC: $e');
    }
  }
  
  Future<void> updateMetadata({
    required String title,
    required String artist,
    String? album,
    String? thumbnail,
  }) async {
    if (!Platform.isWindows || _smtc == null) return;
    
    try {
      await _smtc!.updateMetadata(
        MusicMetadata(
          title: title,
          artist: artist,
          album: album ?? 'Vibra',
          thumbnail: thumbnail,
        ),
      );
      print('🪟 Updated Windows SMTC metadata: $title by $artist');
    } catch (e) {
      print('❌ Failed to update Windows SMTC metadata: $e');
    }
  }
  
  Future<void> updatePlaybackStatus({
    required bool isPlaying,
    required int positionMs,
    required int durationMs,
  }) async {
    if (!Platform.isWindows || _smtc == null) return;
    
    try {
      await _smtc!.setPlaybackStatus(
        isPlaying ? PlaybackStatus.Playing : PlaybackStatus.Paused,
      );
      
      // Try to update timeline with PlaybackTimeline object
      try {
        await _smtc!.updateTimeline(
          PlaybackTimeline(
            startTimeMs: 0,
            endTimeMs: durationMs,
            positionMs: positionMs,
            minSeekTimeMs: 0,
            maxSeekTimeMs: durationMs,
          ),
        );
      } catch (e) {
        print('⚠️ Could not update timeline: $e');
      }
      
      print('🪟 Updated Windows SMTC playback: ${isPlaying ? "Playing" : "Paused"} at ${positionMs}ms');
    } catch (e) {
      print('❌ Failed to update Windows SMTC playback status: $e');
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
