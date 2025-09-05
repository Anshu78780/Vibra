import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_model.dart';
import '../services/audio_service.dart';

class MusicPlayerController extends ChangeNotifier {
  static final MusicPlayerController _instance = MusicPlayerController._internal();
  factory MusicPlayerController() => _instance;
  MusicPlayerController._internal() {
    print('🎵 Initializing MusicPlayerController');
    _setupAudioPlayer();
    
    // Make sure we get onAudioComplete callbacks
    _audioPlayer.playbackEventStream.listen((event) {
      print('🎵 Playback event: $event');
    }, onError: (Object e, StackTrace st) {
      print('❌ Error in playbackEventStream: $e');
    });
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  MusicTrack? _currentTrack;
  List<MusicTrack> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  String _loadingMessage = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _errorMessage;
  Function(String)? _onAutoAdvance; // Callback for auto-advance notifications

  // Getters
  MusicTrack? get currentTrack => _currentTrack;
  List<MusicTrack> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  Duration get duration => _duration;
  Duration get position => _position;
  String? get errorMessage => _errorMessage;
  bool get hasTrack => _currentTrack != null;
  bool get canControl => _currentTrack != null && !_isLoading;

  // Set a callback for auto-advance notifications
  void setAutoAdvanceCallback(Function(String)? callback) {
    _onAutoAdvance = callback;
  }
  
  // Handle track completion, auto-advance if possible
  void _handleTrackCompletion() {
    print('🎵 Handling track completion');
    _isPlaying = false;
    _position = Duration.zero;
    
    // Auto-advance to next track if available
    Future.delayed(Duration.zero, () {
      if (hasNext) {
        final nextTrack = _queue[_currentIndex + 1];
        print('✅✅✅ Auto-playing next track: ${nextTrack.title}');
        _onAutoAdvance?.call('Playing next: ${nextTrack.title}');
        _playNext();
      } else {
        print('Queue completed, no more tracks');
        notifyListeners();
      }
    });
  }

  void _setupAudioPlayer() {
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;
      
      // Log the player state for debugging
      print('Player state changed: playing=$_isPlaying, processingState=${state.processingState}');
      
      // Check if the playback just stopped due to completion
      if (wasPlaying && !_isPlaying && state.processingState == ProcessingState.completed) {
        print('🎵 Track completed detection via playerStateStream');
        _handleTrackCompletion();
      }
      
      if (wasPlaying != _isPlaying) {
        notifyListeners();
      }
    });
    
    // Add a dedicated handler for completion events
    _audioPlayer.processingStateStream
        .where((state) => state == ProcessingState.completed)
        .listen((_) {
      print('🎵🎵🎵 Track completed via processingStateStream');
      _handleTrackCompletion();
    });

    // Listen to duration changes
    _audioPlayer.durationStream.listen((duration) {
      final newDuration = duration ?? Duration.zero;
      if (_duration != newDuration) {
        _duration = newDuration;
        print('Duration changed: ${_formatDuration(_duration)}');
        notifyListeners();
      }
    });

    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      _position = position;
      
      // Check if we're near the end of the track (95% complete)
      // This helps ensure we detect completion even if the completion event is missed
      if (_duration.inMilliseconds > 0 && 
          position.inMilliseconds > _duration.inMilliseconds * 0.95 && 
          !_isLoading &&
          _audioPlayer.processingState == ProcessingState.ready) {
        print('Near end of track: ${position.inSeconds}s / ${_duration.inSeconds}s');
      }
      
      notifyListeners();
    });

    // Listen to processing state changes
    _audioPlayer.processingStateStream.listen((state) {
      print('Processing state: $state');
      
      switch (state) {
        case ProcessingState.idle:
          break;
        case ProcessingState.loading:
          // Keep loading state active
          break;
        case ProcessingState.buffering:
          // Audio is buffering, keep loading active if not yet ready
          if (!_isLoading) {
            _setLoading(true, 'Buffering...');
          }
          break;
        case ProcessingState.ready:
          // Audio is ready to play, clear loading state
          _setLoading(false, '');
          break;
        case ProcessingState.completed:
          // We handle completion in _handleTrackCompletion
          // which is called by the dedicated listener
          print('✅✅✅ Song completed! (processingStateStream)');
          _setLoading(false, '');
          break;
      }
    });

    // Listen to buffered position to handle loading states better
    _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      // If we have some buffered content and were loading, we can clear loading
      if (_isLoading && bufferedPosition > Duration.zero && _duration > Duration.zero) {
        _setLoading(false, '');
      }
    });
  }

  Future<void> playTrack(MusicTrack track) async {
    try {
      print('⏯️ Starting playback of track: ${track.title}');
      _setLoading(true, 'Loading music...');
      _errorMessage = null;
      _currentTrack = track;
      
      // If this track is not in the current queue, create a new queue with just this track
      final trackIndex = _queue.indexWhere((t) => t.webpageUrl == track.webpageUrl);
      if (trackIndex != -1) {
        _currentIndex = trackIndex;
        print('🎵 Playing from existing queue at index $_currentIndex');
      } else {
        _queue = [track];
        _currentIndex = 0;
        print('🎵 Created new queue with single track');
      }
      
      notifyListeners();

      // Extract video ID from YouTube URL
      final videoId = _extractVideoId(track.webpageUrl);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }
      print('🎬 Extracted video ID: $videoId');

      _setLoading(true, 'Getting audio stream...');
      
      // Get audio URL using youtube_explode_dart
      final audioUrl = await AudioService.getAudioUrl(videoId);
      print('🔗 Got audio URL of length: ${audioUrl.length}');
      
      _setLoading(true, 'Preparing playback...');
      
      // Stop any current playback before setting the new source
      if (_audioPlayer.playing) {
        print('⏹️ Stopping current playback before loading new track');
        await _audioPlayer.stop();
      }
      
      // Set the audio source
      print('🔊 Setting audio URL');
      await _audioPlayer.setUrl(audioUrl);
      
      print('▶️ Starting playback');
      // Start playback
      await _audioPlayer.play();
      print('✅ Playback started successfully');
      
    } catch (e) {
      _setLoading(false, '');
      _errorMessage = e.toString();
      print('❌ Error playing track: $e');
      notifyListeners();
    }
  }

  Future<void> playTrackFromQueue(List<MusicTrack> queue, int index) async {
    if (index < 0 || index >= queue.length) return;
    
    print('Setting queue with ${queue.length} tracks, playing index $index');
    _queue = List.from(queue);
    _currentIndex = index;
    final track = _queue[index];
    
    // Stop current track first
    await _audioPlayer.stop();
    
    // Reset player state before playing new track
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    
    // Play the selected track
    await playTrack(track);
  }

  Future<void> _playNext() async {
    if (hasNext) {
      print('Playing next track at index: ${_currentIndex + 1}');
      _currentIndex++;
      final nextTrack = _queue[_currentIndex];
      _currentTrack = nextTrack;
      
      // Make sure we stop the current playback before starting a new one
      await _audioPlayer.stop();
      
      // Start playing the next track
      await playTrack(nextTrack);
      
      print('Successfully started playing next track: ${nextTrack.title}');
    } else {
      print('No more tracks in queue');
    }
  }

  Future<void> playNext() async {
    await _playNext();
  }

  Future<void> playPrevious() async {
    if (hasPrevious) {
      _currentIndex--;
      final previousTrack = _queue[_currentIndex];
      _currentTrack = previousTrack;
      await playTrack(previousTrack);
    }
  }

  // Set the entire queue
  void setQueue(List<MusicTrack> tracks) {
    _queue = List.from(tracks);
    notifyListeners();
  }

  void addToQueue(MusicTrack track) {
    _queue.add(track);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    
    if (index == _currentIndex) {
      // If removing current track, stop playback
      stop();
    } else if (index < _currentIndex) {
      // If removing a track before current, adjust current index
      _currentIndex--;
    }
    
    _queue.removeAt(index);
    notifyListeners();
  }

  void clearQueue() {
    stop();
    _queue.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  Future<void> pause() async {
    if (!canControl) return;
    try {
      await _audioPlayer.pause();
    } catch (e) {
      print('Error pausing: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (!canControl) return;
    try {
      await _audioPlayer.play();
    } catch (e) {
      print('Error resuming: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentTrack = null;
    _isPlaying = false;
    _position = Duration.zero;
    // Don't clear the queue on stop, just reset position
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    print('Seeking to position: ${position.inSeconds}s');
    if (!canControl || _duration == Duration.zero) {
      print('Cannot seek: canControl=$canControl, duration=${_duration.inMilliseconds}ms');
      return;
    }
    try {
      // Ensure the position is within bounds
      final clampedPosition = Duration(
        milliseconds: position.inMilliseconds.clamp(0, _duration.inMilliseconds),
      );
      print('Seeking to clamped position: ${clampedPosition.inSeconds}s');
      await _audioPlayer.seek(clampedPosition);
    } catch (e) {
      print('Error seeking: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _setLoading(bool loading, String message) {
    _isLoading = loading;
    _loadingMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> retry() async {
    if (_currentTrack != null) {
      await playTrack(_currentTrack!);
    }
  }

  String? _extractVideoId(String url) {
    // Extract video ID from various YouTube URL formats
    final regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  String get formattedPosition {
    return _formatDuration(_position);
  }

  String get formattedDuration {
    return _formatDuration(_duration);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
