import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

// A minimal AudioHandler that wraps a JustAudio player and exposes
// play/pause/seek/skip for lock screen and notification controls.
class BackgroundAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final Future<void> Function()? _onSkipNext;
  final Future<void> Function()? _onSkipPrevious;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;

  BackgroundAudioHandler(
    this._player, {
    Future<void> Function()? onSkipNext,
    Future<void> Function()? onSkipPrevious,
  })  : _onSkipNext = onSkipNext,
        _onSkipPrevious = onSkipPrevious {
    _init();
  }

  Future<void> _init() async {
    // Configure audio focus/session - improved for better background handling
    if (!Platform.isWindows) {
      try {
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false, // Continue playing when other apps use audio
        ));
        print('✅ Audio session configured for background playback');
      } catch (e) {
        print('Warning: Could not configure audio session: $e');
      }
    }

    // Map just_audio state to audio_service playbackState + position
    _playerStateSub = _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = () {
        switch (state.processingState) {
          case ProcessingState.idle:
            return AudioProcessingState.idle;
          case ProcessingState.loading:
            return AudioProcessingState.loading;
          case ProcessingState.buffering:
            return AudioProcessingState.buffering;
          case ProcessingState.ready:
            return AudioProcessingState.ready;
          case ProcessingState.completed:
            return AudioProcessingState.completed;
        }
      }();

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekBackward,
          MediaAction.seekForward,
          MediaAction.setSpeed,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });

    _durationSub = _player.durationStream.listen((d) {
      final currentItem = mediaItem.value;
      if (currentItem == null) return;
      mediaItem.add(currentItem.copyWith(duration: d));
    });

    _positionSub = _player.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));
    });
  }

  // Public API to update metadata from UI/controller
  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
    // Push single-item queue for nice UI on some platforms
    queue.add([mediaItem]);
    
    // On Windows, also explicitly update playback state to force system media controls refresh
    if (Platform.isWindows) {
      final currentState = playbackState.value;
      playbackState.add(currentState.copyWith(
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
      ));
    }
  }

  // Standard transport controls
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_onSkipNext != null) {
      await _onSkipNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_onSkipPrevious != null) {
      await _onSkipPrevious();
    }
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    // No-op here; the UI can subscribe to custom events if needed.
    return null;
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  void close() {
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
  }
}

Future<AudioHandler> initBackgroundAudio(
  AudioPlayer player, {
  Future<void> Function()? onSkipNext,
  Future<void> Function()? onSkipPrevious,
}) {
  return AudioService.init(
    builder: () => BackgroundAudioHandler(
      player,
      onSkipNext: onSkipNext,
      onSkipPrevious: onSkipPrevious,
    ),
  config: AudioServiceConfig(
    androidNotificationChannelId: 'com.vibra.audio',
    androidNotificationChannelName: 'Music Playback',
    androidNotificationChannelDescription: 'Controls for music playback',
    androidNotificationIcon: 'drawable/ic_vibra_notification',
    androidNotificationOngoing: false, 
    androidStopForegroundOnPause: false, // Keep service alive when paused
    androidNotificationClickStartsActivity: true,
    preloadArtwork: true,
    // Windows-specific optimizations
    androidShowNotificationBadge: !Platform.isWindows,
    androidResumeOnClick: !Platform.isWindows,
    // Enable faster media item updates for Windows
    fastForwardInterval: const Duration(seconds: 10),
    rewindInterval: const Duration(seconds: 10),
  ),
  );
}

extension AudioHandlerQueueExt on AudioHandler {
  Future<void> updateQueue(List<MediaItem> items) async {
    try {
      // ignore: invalid_use_of_visible_for_testing_member
      (this as dynamic).queue.add(items);
    } catch (_) {
      // Fallback for older versions; not critical.
    }
  }
}
