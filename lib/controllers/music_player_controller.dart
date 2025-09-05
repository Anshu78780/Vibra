import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_model.dart';
import '../services/audio_service.dart';

class MusicPlayerController extends ChangeNotifier {
  static final MusicPlayerController _instance = MusicPlayerController._internal();
  factory MusicPlayerController() => _instance;
  MusicPlayerController._internal() {
    _setupAudioPlayer();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  MusicTrack? _currentTrack;
  bool _isPlaying = false;
  bool _isLoading = false;
  String _loadingMessage = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _errorMessage;

  // Getters
  MusicTrack? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  Duration get duration => _duration;
  Duration get position => _position;
  String? get errorMessage => _errorMessage;
  bool get hasTrack => _currentTrack != null;

  void _setupAudioPlayer() {
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;
      if (wasPlaying != _isPlaying) {
        print('Player state changed: playing=$_isPlaying');
        notifyListeners();
      }
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
      notifyListeners();
    });

    // Listen to playback completion
    _audioPlayer.processingStateStream.listen((state) {
      print('Processing state: $state');
      if (state == ProcessingState.completed) {
        _isPlaying = false;
        _position = Duration.zero;
        notifyListeners();
      }
    });
  }

  Future<void> playTrack(MusicTrack track) async {
    try {
      _setLoading(true, 'Loading music...');
      _errorMessage = null;
      _currentTrack = track;
      notifyListeners();

      // Extract video ID from YouTube URL
      final videoId = _extractVideoId(track.webpageUrl);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }

      _setLoading(true, 'Getting audio stream...');
      
      // Get audio URL using youtube_explode_dart
      final audioUrl = await AudioService.getAudioUrl(videoId);
      
      _setLoading(true, 'Preparing playback...');
      
      // Set the audio source
      await _audioPlayer.setUrl(audioUrl);
      
      _setLoading(false, '');
      
      // Start playback
      await _audioPlayer.play();
      
    } catch (e) {
      _setLoading(false, '');
      _errorMessage = e.toString();
      print('Error playing track: $e');
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentTrack = null;
    _isPlaying = false;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void _setLoading(bool loading, String message) {
    _isLoading = loading;
    _loadingMessage = message;
    notifyListeners();
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
