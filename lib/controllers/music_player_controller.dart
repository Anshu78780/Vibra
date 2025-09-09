import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io' show Platform;
import 'dart:async';
import '../models/music_model.dart';
import '../services/audio_service.dart' as yt_audio_service;
import '../services/background_audio_handler.dart';
import '../services/recommendation_service.dart';
import '../services/preloading_service.dart';
import '../services/download_service.dart';
import '../services/windows_media_service.dart';
import '../services/youtube_fallback_service.dart';
import '../services/song_history_service.dart';

class MusicPlayerController extends ChangeNotifier {
  static final MusicPlayerController _instance = MusicPlayerController._internal();
  factory MusicPlayerController() => _instance;
  MusicPlayerController._internal() {
    print('🎵 Initializing MusicPlayerController');
  _setupAudioPlayer();
  // Background audio handler is now lazily initialized via _ensureAudioHandler()
    _initDownloadService();
    _initWindowsMediaService();
    
    // Make sure we get onAudioComplete callbacks
    _audioPlayer.playbackEventStream.listen((event) {
      print('🎵 Playback event: $event');
    }, onError: (Object e, StackTrace st) {
      print('❌ Error in playbackEventStream: $e');
    });
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioHandler? _audioHandler;
  Future<AudioHandler?>? _audioHandlerInit; // Guards concurrent init calls
  
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
  bool _isHandlingCompletion = false; // Flag to prevent duplicate completion handling
  String? _lastRecommendationTrackId; // Track the last track for which recommendations were loaded
  String? _pendingTrackId; // Track ID of the song that should be played next (for quick clicks)
  Timer? _windowsSmtcTimer; // Timer to periodically refresh Windows SMTC

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

  Future<AudioHandler?> _ensureAudioHandler() async {
    // If already created, return immediately
    if (_audioHandler != null) return _audioHandler;
    // If an initialization is in-flight, await it
    if (_audioHandlerInit != null) return _audioHandlerInit;
    // Start a single initialization future
    _audioHandlerInit = _initBackgroundAudio().then((_) => _audioHandler);
    return _audioHandlerInit;
  }
  
  // Handle track completion, auto-advance if possible
  void _handleTrackCompletion() {
    print('🎵 Handling track completion');
    
    // Prevent duplicate completion handling
    if (_isHandlingCompletion) {
      print('🔄 Already handling completion, skipping duplicate call');
      return;
    }
    
    _isHandlingCompletion = true;
    _isPlaying = false;
    _position = Duration.zero;
    
    // Debug queue status before deciding what to do
    debugQueueStatus();
    
    // Auto-advance to next track if available
    Future.delayed(Duration.zero, () async {
      if (hasNext) {
        final nextTrack = _queue[_currentIndex + 1];
        print('✅✅✅ Auto-playing next track: ${nextTrack.title} (ID: ${nextTrack.id})');
        print('🔍 Current track was: ${_currentTrack?.title ?? 'Unknown'} (ID: ${_currentTrack?.id ?? 'Unknown'})');
        _onAutoAdvance?.call('Playing next: ${nextTrack.title}');
        _playNext().then((_) {
          // Reset the flag after playback starts
          _isHandlingCompletion = false;
        });
      } else {
        print('Queue completed, no more tracks');
        _isHandlingCompletion = false;
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
      
      // Update Windows media controls more frequently to maintain visibility
      if (Platform.isWindows && _currentTrack != null) {
        // Update every 3 seconds or when position is at significant milestones
        final shouldUpdate = _position.inSeconds % 3 == 0 || 
                           _position.inSeconds % 10 == 0 ||
                           _position.inMilliseconds == 0;
                           
        if (shouldUpdate) {
          WindowsMediaService.instance.updatePlaybackStatus(
            isPlaying: _isPlaying,
            positionMs: _position.inMilliseconds,
            durationMs: _duration.inMilliseconds,
          );
        }
      }
      
      // Check if we should preload the next track (30 seconds before end)
      if (_duration.inMilliseconds > 0 && hasNext) {
        final secondsLeft = (_duration.inMilliseconds - position.inMilliseconds) / 1000;
        
        if (secondsLeft <= 30 && secondsLeft > 25) {
          print('⏳ Approaching end of track: ${position.inSeconds}s / ${_duration.inSeconds}s');
          print('🔄 Preloading next track...') ;
          // Start preloading when there are 30 seconds left (with 5-second buffer to avoid spam)
          _preloadNextTrack();
        }
      }
      
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

  Future<void> _initBackgroundAudio() async {
    try {
      if (_audioHandler != null) {
        print('ℹ️ AudioHandler already initialized, skipping');
        return;
      }
      _audioHandler = await initBackgroundAudio(
        _audioPlayer,
        onSkipNext: () async => await playNext(),
        onSkipPrevious: () async => await playPrevious(),
      );
      print('✅ AudioHandler initialized');
    } catch (e) {
      print('❌ Failed to init AudioHandler: $e');
      // On Windows, continue without audio service - the player will still work
      if (Platform.isWindows) {
        print('ℹ️ Continuing without background audio service on Windows');
      }
    }
  }

  Future<void> _initDownloadService() async {
    try {
      await DownloadService().initialize();
      print('✅ DownloadService initialized');
    } catch (e) {
      print('❌ Failed to init DownloadService: $e');
    }
  }

  Future<void> _initWindowsMediaService() async {
    if (!Platform.isWindows) return;
    
    try {
      await WindowsMediaService.instance.initialize();
      
      // Set up Windows media control button handlers
      await WindowsMediaService.instance.setButtonPressHandler(
        onPlay: () => resume(),
        onPause: () => pause(),
        onNext: () => playNext(),
        onPrevious: () => playPrevious(),
        onStop: () => stop(),
        onSeek: (positionMs) => seek(Duration(milliseconds: positionMs)),
      );
      
      // Start periodic timer to keep SMTC visible (every 15 seconds)
      _windowsSmtcTimer?.cancel();
      _windowsSmtcTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_currentTrack != null && Platform.isWindows) {
          WindowsMediaService.instance.forceShow();
        }
      });
      
      print('✅ Windows Media Service initialized with periodic refresh');
    } catch (e) {
      print('❌ Failed to init Windows Media Service: $e');
    }
  }

  // Windows-specific method to refresh media controls
  Future<void> _refreshWindowsMediaControls() async {
    if (!Platform.isWindows || _currentTrack == null) {
      return;
    }
    
    try {
      // Update regular audio service
      if (_audioHandler != null) {
        final item = _toMediaItem(_currentTrack!, duration: _audioPlayer.duration);
        await _audioHandler!.updateMediaItem(item);
      }
      
      // Always ensure Windows Media Service is initialized
      if (!WindowsMediaService.instance.isInitialized) {
        await WindowsMediaService.instance.initialize();
        // Small delay to ensure initialization completes
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // Update Windows SystemMediaTransportControls with retry logic
      await WindowsMediaService.instance.updateMetadata(
        title: _currentTrack!.title,
        artist: _currentTrack!.artist,
        album: _currentTrack!.album,
        thumbnail: _currentTrack!.thumbnail,
      );
      
      await WindowsMediaService.instance.updatePlaybackStatus(
        isPlaying: _isPlaying,
        positionMs: _position.inMilliseconds,
        durationMs: _duration.inMilliseconds,
      );
      
      // Force the SMTC to show
      await WindowsMediaService.instance.forceShow();
      
      print('🪟 Refreshed Windows media controls for: ${_currentTrack!.title}');
    } catch (e) {
      print('❌ Failed to refresh Windows media controls: $e');
      // Try to reinitialize on failure
      try {
        await WindowsMediaService.instance.initialize();
      } catch (reinitError) {
        print('❌ Failed to reinitialize Windows media service: $reinitError');
      }
    }
  }

  // Helper method to check if the current track loading operation is cancelled
  bool _isTrackLoadingCancelled(MusicTrack track) {
    final trackId = track.id.isNotEmpty ? track.id : track.webpageUrl;
    return _pendingTrackId != trackId;
  }
  
  Future<void> playTrack(MusicTrack track) async {
    try {
      // Extract track ID for tracking quick clicks
      final currentTrackId = track.id.isNotEmpty ? track.id : track.webpageUrl;
      
      // Set this as the pending track
      _pendingTrackId = currentTrackId;
      
      print('⏯️ Starting playback of track: ${track.title} (ID: $currentTrackId)');
      _setLoading(true, 'Loading music...');
      _errorMessage = null;
      _isHandlingCompletion = false; // Reset completion flag for new track
      
      // Immediately stop any current playback before doing anything else
      if (_audioPlayer.playing) {
        print('⏹️ Stopping current playback immediately');
        await _audioPlayer.stop();
        _isPlaying = false;
        notifyListeners(); // Update UI to show stopped state
      }
      
      // Check if we're still the pending track (no newer requests came in)
      if (_isTrackLoadingCancelled(track)) {
        print('⏹️ Cancelling playback because newer track was requested');
        return; // Exit early, don't continue with this track
      }
      
      await _ensureAudioHandler();
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

      // Check if this is a local file (starts with file:// or is a local path)
      if (track.webpageUrl.startsWith('file://') || track.webpageUrl.startsWith('/') || track.webpageUrl.contains('\\')) {
        print('🎵 Playing local file: ${track.webpageUrl}');
        
        // Check if we're still the pending track (no newer requests came in)
        if (_isTrackLoadingCancelled(track)) {
          print('⏹️ Cancelling playback because newer track was requested (before local file play)');
          return;
        }
        
        _setLoading(true, 'Loading local file...');
        
        // For local files, use the webpageUrl directly as the audio URL
        await _playAudioUrl(track, track.webpageUrl);
        return;
      }

      // Extract video ID from YouTube URL for online tracks
      final videoId = _extractVideoId(track.webpageUrl);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }
      print('🎬 Extracted video ID: $videoId');
      
      // Check if we're still the pending track (no newer requests came in)
      if (_isTrackLoadingCancelled(track)) {
        print('⏹️ Cancelling playback because newer track was requested (before audio URL fetch)');
        return; // Exit early, don't continue with this track
      }

      _setLoading(true, 'Getting audio stream...');
      
      // Check if track is downloaded locally first
      String audioUrl;
      final downloadedPath = await DownloadService().getDownloadedAudioPath(track);
      
      // Check again if cancelled
      if (_isTrackLoadingCancelled(track)) {
        print('⏹️ Cancelling playback because newer track was requested (after path check)');
        return;
      }
      
      if (downloadedPath != null) {
        audioUrl = 'file://$downloadedPath';
        print('🎵 Using downloaded file for: ${track.title}');
        _setLoading(true, 'Loading from local storage...');
      } else {
        // Check if we have a preloaded audio URL for this track
        if (PreloadingService.isPreloaded(track)) {
          final preloadedUrl = await PreloadingService.getPreloadedAudioUrl(track);
          
          // Check again if cancelled
          if (_isTrackLoadingCancelled(track)) {
            print('⏹️ Cancelling playback because newer track was requested (after preload check)');
            return;
          }
          
          if (preloadedUrl != null) {
            audioUrl = preloadedUrl;
            print('🚀 Using preloaded audio URL for: ${track.title}');
            _setLoading(true, 'Loading from cache...');
          } else {
            // Fallback to fresh URL if preloaded URL is null
            audioUrl = await yt_audio_service.AudioService.getAudioUrl(videoId);
            
            // Check again if cancelled
            if (_isTrackLoadingCancelled(track)) {
              print('⏹️ Cancelling playback because newer track was requested (after fallback URL fetch)');
              return;
            }
            
            print('🔗 Got fresh audio URL (preload failed) of length: ${audioUrl.length}');
          }
        } else {
          // Get audio URL using youtube_explode_dart
          audioUrl = await yt_audio_service.AudioService.getAudioUrl(videoId);
          
          // Check again if cancelled
          if (_isTrackLoadingCancelled(track)) {
            print('⏹️ Cancelling playback because newer track was requested (after URL fetch)');
            return;
          }
          
          print('🔗 Got fresh audio URL of length: ${audioUrl.length}');
        }
      }
      
      // Use the common playback method
      await _playAudioUrl(track, audioUrl);
      
    } catch (e) {
      _setLoading(false, '');
      print('❌ Error playing track: $e');
      
      // Check if this is a VideoUnplayableException and try fallback
      if (e.toString().contains('VideoUnplayableException') || 
          e.toString().contains('This video is not available') ||
          e.toString().contains('Streams are not available for this video')) {
        
        print('🔄 Video is unplayable, attempting fallback search...');
        _setLoading(true, 'Searching for alternative version...');
        
        try {
          final alternativeTrack = await YouTubeFallbackService.findAlternativeTrack(track);
          
          if (alternativeTrack != null) {
            // Check if the original request was cancelled while searching for alternative
            if (_isTrackLoadingCancelled(track)) {
              print('⏹️ Cancelling alternative track loading because newer track was requested');
              return;
            }
            
            print('✅ Found alternative track: ${alternativeTrack.title} by ${alternativeTrack.artist}');
            print('🔗 Alternative URL: ${alternativeTrack.webpageUrl}');
            _setLoading(true, 'Loading alternative version with recommendations...');
            
            // Use playTrackWithRecommendations to ensure continuous playback
            await playTrackWithRecommendations(alternativeTrack);
            return; // Exit successfully
          } else {
            print('❌ No alternative track found');
            
            // Only set error if not cancelled
            if (!_isTrackLoadingCancelled(track)) {
              _errorMessage = 'This video is not available and no alternative version could be found. The video may be restricted in your region or has been removed.';
            }
          }
        } catch (fallbackError) {
          print('❌ Fallback search failed: $fallbackError');
          _errorMessage = 'This video is not available and the search for alternatives failed: $fallbackError';
        }
      } else {
        _errorMessage = e.toString();
      }
      
      notifyListeners();
    }
  }

  Future<void> playTrackFromQueue(List<MusicTrack> queue, int index) async {
    if (index < 0 || index >= queue.length) return;
    
    print('Setting queue with ${queue.length} tracks, playing index $index');
    await _ensureAudioHandler();
    
    // Show loading state immediately
    _setLoading(true, 'Loading track...');
    
    // Reset recommendation tracking when setting a new queue
    _lastRecommendationTrackId = null;
    
    _queue = List.from(queue);
    _currentIndex = index;
    final track = _queue[index];

    // Update queue for system UI
    final items = _queue.map((t) => _toMediaItem(t)).toList();
    try {
      await _audioHandler?.updateQueue(items);
    } catch (_) {}
    
    // Stop current track first
    print('⏹️ Stopping current playback before loading new track from queue');
    await _audioPlayer.stop();
    
    // Reset player state before playing new track
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    
    // Play the selected track
    await playTrack(track);
  }

  /// Play a track and build queue using recommendations
  Future<void> playTrackWithRecommendations(MusicTrack track) async {
    try {
      // Extract track ID for tracking quick clicks
      final currentTrackId = track.id.isNotEmpty ? track.id : track.webpageUrl;
      
      print('🎵 Playing track with recommendations: ${track.title}');
      
      // Mark this as the pending track
      _pendingTrackId = currentTrackId;
      
      // Start loading recommendations IMMEDIATELY - don't wait for track to start
      print('🚀 Starting IMMEDIATE recommendation loading for: ${track.title}');
      _loadRecommendationsEarly(track);
      
      // Show loading state immediately
      _setLoading(true, 'Loading music...');
      
      // Stop any current playback immediately
      if (_audioPlayer.playing) {
        print('⏹️ Stopping current playback immediately in playTrackWithRecommendations');
        await _audioPlayer.stop();
        _isPlaying = false;
        notifyListeners(); // Update UI to show stopped state
      }
      
      // Check if we're still the current requested track
      if (_isTrackLoadingCancelled(track)) {
        print('⏹️ Cancelling recommendations playback because newer track was requested');
        return;
      }
      
      // Reset recommendation tracking for new track
      _lastRecommendationTrackId = null;
      
      // Start playing the track immediately
      _queue = [track];
      _currentIndex = 0;
      await playTrack(track);
      
      // The recommendations are already loading in the background via recommendationsFuture
      
    } catch (e) {
      print('❌ Error playing track with recommendations: $e');
      // Fallback to regular playback if not cancelled
      if (!_isTrackLoadingCancelled(track)) {
        await playTrack(track);
      }
    }
  }

  /// Load recommendations early (as soon as track is requested)
  Future<void> _loadRecommendationsEarly(MusicTrack track) async {
    print('🎯 BACKGROUND: Starting _loadRecommendationsInBackground for: ${track.title}');
    try {
      // Skip recommendations for local files
      if (track.webpageUrl.startsWith('file://') || track.webpageUrl.startsWith('/') || track.webpageUrl.contains('\\')) {
        print('🎵 Skipping recommendations for local file: ${track.title}');
        return;
      }
      
      final videoId = _extractVideoId(track.webpageUrl);
      print('🎯 BACKGROUND: Extracted video ID: $videoId');
      if (videoId == null) {
        print('❌ Could not extract video ID from: ${track.webpageUrl}');
        return;
      }
      
      // Check if we've already loaded recommendations for this track
      if (_lastRecommendationTrackId == videoId) {
        print('� Recommendations already loaded for this track, skipping...');
        return;
      }
      
      print('�🔍 Getting recommendations for: ${track.title} (ID: $videoId)');
      final recommendations = await RecommendationService.getRecommendations(videoId);
      
      print('📦 Received ${recommendations.length} recommendations from API');
      
      if (recommendations.isNotEmpty) {
        // Filter out the current track and duplicates from recommendations
        final filteredRecommendations = recommendations.where((rec) {
          // Don't add the current track again
          if (_areTracksEqual(rec, track)) {
            print('🚫 Filtering out current track: ${rec.title} (ID: ${rec.id})');
            return false;
          }
          
          // Don't add tracks that are already in the queue
          final alreadyInQueue = _queue.any((existing) => _areTracksEqual(existing, rec));
          if (alreadyInQueue) {
            print('🚫 Filtering out duplicate track: ${rec.title} (ID: ${rec.id})');
            return false;
          }
          
          print('✅ Adding unique track: ${rec.title} (ID: ${rec.id})');
          return true;
        }).toList();
        
        print('📦 Filtered ${recommendations.length} recommendations down to ${filteredRecommendations.length} unique tracks');
        
        // Update the queue with filtered recommendations (keep current track at index 0)
        final oldQueueLength = _queue.length;
        _queue = [track, ...filteredRecommendations];
        _lastRecommendationTrackId = videoId; // Mark this track as having recommendations loaded
        print('✅ Updated queue from $oldQueueLength to ${_queue.length} tracks');
        print('📋 First 3 queue tracks:');
        for (int i = 0; i < _queue.length && i < 3; i++) {
          print('  ${i}: ${_queue[i].title} by ${_queue[i].artist}');
        }
        
        // Update the system UI queue
        final items = _queue.map((t) => _toMediaItem(t)).toList();
        try {
          await _audioHandler?.updateQueue(items);
          print('📱 Updated system UI queue successfully');
        } catch (e) {
          print('❌ Failed to update system UI queue: $e');
        }
        
        // Preload the first filtered recommendation if available
        if (filteredRecommendations.isNotEmpty) {
          PreloadingService.preloadAudioUrl(filteredRecommendations.first);
          print('🔄 Started preloading: ${filteredRecommendations.first.title}');
        }
        
        notifyListeners();
        print('✅ Queue update complete and listeners notified');
      } else {
        print('⚠️ No recommendations found for: ${track.title}');
        // Mark as attempted even if no recommendations found to avoid retrying immediately
        _lastRecommendationTrackId = videoId;
      }
    } catch (e) {
      print('❌ Error loading recommendations: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      // Mark as attempted even if error occurred to avoid infinite retries
      final videoId = _extractVideoId(track.webpageUrl);
      if (videoId != null) {
        _lastRecommendationTrackId = videoId;
      }
    }
  }

  Future<void> _playNext() async {
    if (hasNext) {
      print('Playing next track at index: ${_currentIndex + 1}');
      final originalIndex = _currentIndex;
      _currentIndex++;
      final nextTrack = _queue[_currentIndex];
      
      // Safety check: if the next track is the same as current track, skip it
      if (_currentTrack != null && _areTracksEqual(nextTrack, _currentTrack!)) {
        print('🚫 Next track is identical to current track, skipping...');
        
        // Try to find a different track in the queue
        while (hasNext && _areTracksEqual(_queue[_currentIndex], _currentTrack!)) {
          _currentIndex++;
          if (_currentIndex >= _queue.length) {
            break;
          }
        }
        
        // If we've reached the end without finding a different track
        if (_currentIndex >= _queue.length) {
          print('🛑 No more unique tracks in queue');
          _currentIndex = originalIndex; // Reset to original position
          return;
        }
      }
      
      final finalNextTrack = _queue[_currentIndex];
      
      // Show loading indicator before stopping current track
      _setLoading(true, 'Loading next track...');
      
      // Make sure we stop the current playback before starting a new one
      print('⏹️ Stopping current playback before loading next track');
      await _audioPlayer.stop();
      
      // Small delay to ensure the audio system has fully stopped
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Update current track after stopping
      _currentTrack = finalNextTrack;
      
      // Reset position
      _position = Duration.zero;
      
      // Start playing the next track
      await playTrack(finalNextTrack);
      
      print('Successfully started playing next track: ${finalNextTrack.title}');
    } else {
      print('No more tracks in queue');
    }
  }

  Future<void> playNext() async {
    // Show loading state immediately for better UX
    _setLoading(true, 'Loading next track...');
    
    // Stop any current playback immediately
    if (_audioPlayer.playing) {
      print('⏹️ Stopping current playback immediately in playNext()');
      await _audioPlayer.stop();
      _isPlaying = false;
      notifyListeners(); // Update UI to show stopped state
    }
    
    await _playNext();
  }

  Future<void> playPrevious() async {
    if (hasPrevious) {
      // Show loading state immediately
      _setLoading(true, 'Loading previous track...');
      
      // Stop any current playback immediately
      if (_audioPlayer.playing) {
        print('⏹️ Stopping current playback immediately in playPrevious()');
        await _audioPlayer.stop();
        _isPlaying = false;
        notifyListeners(); // Update UI to show stopped state
        
        // Small delay to ensure the audio system has time to respond
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      _currentIndex--;
      final previousTrack = _queue[_currentIndex];
      
      // Update current track after stopping
      _currentTrack = previousTrack;
      
      // Reset position
      _position = Duration.zero;
      
      await playTrack(previousTrack);
    }
  }

  /// Preload the next track's audio URL for seamless playback
  Future<void> _preloadNextTrack() async {
    if (!hasNext) return;
    
    final nextTrack = _queue[_currentIndex + 1];
    
    // Check if already preloaded
    if (PreloadingService.isPreloaded(nextTrack)) {
      print('🔄 Next track already preloaded: ${nextTrack.title}');
      return;
    }
    
    print('🔄 Starting preload for next track: ${nextTrack.title}');
    try {
      await PreloadingService.preloadAudioUrl(nextTrack);
      print('✅ Successfully preloaded: ${nextTrack.title}');
    } catch (e) {
      print('❌ Failed to preload ${nextTrack.title}: $e');
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
      // Refresh Windows media controls on pause and ensure visibility
      if (Platform.isWindows) {
        await _refreshWindowsMediaControls();
        // Additional force show to ensure SMTC remains visible
        await WindowsMediaService.instance.forceShow();
      }
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
      // Refresh Windows media controls on resume and ensure visibility
      if (Platform.isWindows) {
        await _refreshWindowsMediaControls();
        // Additional force show to ensure SMTC remains visible
        await WindowsMediaService.instance.forceShow();
      }
    } catch (e) {
      print('Error resuming: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> stop() async {
  await _audioPlayer.stop();
  await _audioHandler?.stop();
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

  /// Manually search for and play an alternative version of the current track
  Future<void> searchAlternativeTrack() async {
    if (_currentTrack == null) return;
    
    _setLoading(true, 'Searching for alternative version...');
    
    try {
      final alternativeTrack = await YouTubeFallbackService.findAlternativeTrack(_currentTrack!);
      
      if (alternativeTrack != null) {
        print('✅ Manual alternative search found: ${alternativeTrack.title} by ${alternativeTrack.artist}');
        _setLoading(true, 'Loading alternative with recommendations...');
        await playTrackWithRecommendations(alternativeTrack);
      } else {
        _setLoading(false, '');
        _errorMessage = 'No alternative version found for this track.';
        notifyListeners();
      }
    } catch (e) {
      _setLoading(false, '');
      _errorMessage = 'Failed to search for alternative: $e';
      notifyListeners();
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

  /// Common method to play audio from a URL (local or remote)
  Future<void> _playAudioUrl(MusicTrack track, String audioUrl) async {
    _setLoading(true, 'Preparing playback...');
    
    // Double-check that playback is stopped (redundant but ensures clean state)
    if (_audioPlayer.playing) {
      print('⏹️ Double-checking that playback is stopped');
      await _audioPlayer.stop();
      // Small delay to ensure the audio system has time to respond
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Check again if cancelled before setting audio source
    if (_isTrackLoadingCancelled(track)) {
      print('⏹️ Cancelling playback because newer track was requested (before setting audio source)');
      return;
    }
    
    // Prepare lock screen metadata early (even before play)
    final preItem = _toMediaItem(track);
    await _audioHandler?.updateMediaItem(preItem);

    // Set the audio source
    print('🔊 Setting audio URL: ${audioUrl.length > 100 ? audioUrl.substring(0, 100) + '...' : audioUrl}');
    await _audioPlayer.setUrl(audioUrl);
    
    // Final check before starting playback
    if (_isTrackLoadingCancelled(track)) {
      print('⏹️ Cancelling playback because newer track was requested (after setting URL but before play)');
      return;
    }
    
    print('▶️ Starting playback');
    // Start playback
    await _audioPlayer.play();
    print('✅ Playback started successfully');
    
    // Add track to history when playback starts successfully
    try {
      await SongHistoryService().addToHistory(track);
      print('📝 Added track to history: ${track.title}');
    } catch (e) {
      print('⚠️ Failed to add track to history: $e');
    }

    // Update metadata with actual duration after setUrl
    final item = _toMediaItem(track, duration: _audioPlayer.duration);
    await _audioHandler?.updateMediaItem(item);
    
    // Additional Windows media control refresh - immediate and forced
    if (Platform.isWindows) {
      await _refreshWindowsMediaControls();
      // Force show with a small delay to ensure it sticks
      await Future.delayed(const Duration(milliseconds: 300));
      await WindowsMediaService.instance.forceShow();
    }
  }

  String get formattedPosition {
    return _formatDuration(_position);
  }

  String get formattedDuration {
    return _formatDuration(_duration);
  }

  /// Debug method to check queue status
  void debugQueueStatus() {
    print('🔍 DEBUG QUEUE STATUS:');
    print('  Current Index: $_currentIndex');
    print('  Queue Length: ${_queue.length}');
    print('  Has Next: $hasNext');
    print('  Last Recommendation Track ID: $_lastRecommendationTrackId');
    print('  Current Track ID: ${_currentTrack != null ? _extractVideoId(_currentTrack!.webpageUrl) : 'None'}');
    
    for (int i = 0; i < _queue.length && i < 5; i++) {
      final indicator = i == _currentIndex ? '→ ' : '  ';
      print('  $indicator$i: ${_queue[i].title} by ${_queue[i].artist}');
    }
    if (_queue.length > 5) {
      print('  ... and ${_queue.length - 5} more tracks');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Check if two tracks are the same (by ID or URL)
  bool _areTracksEqual(MusicTrack track1, MusicTrack track2) {
    // Compare by ID first (most reliable)
    if (track1.id.isNotEmpty && track2.id.isNotEmpty && track1.id == track2.id) {
      return true;
    }
    
    // Fallback to webpage URL comparison
    if (track1.webpageUrl.isNotEmpty && track2.webpageUrl.isNotEmpty && track1.webpageUrl == track2.webpageUrl) {
      return true;
    }
    
    return false;
  }

  MediaItem _toMediaItem(MusicTrack t, {Duration? duration}) {
    return MediaItem(
      id: t.id.isNotEmpty ? t.id : t.webpageUrl,
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: duration ?? (t.duration > 0 ? Duration(seconds: t.duration) : null),
      artUri: t.thumbnail.isNotEmpty ? Uri.tryParse(t.thumbnail) : null,
      extras: {
        'webpageUrl': t.webpageUrl,
        'source': t.source,
      },
    );
  }

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  // Download functionality
  Future<void> downloadCurrentTrack() async {
    if (_currentTrack == null) return;
    
    try {
      await DownloadService().downloadTrack(_currentTrack!);
      print('✅ Download started for: ${_currentTrack!.title}');
    } catch (e) {
      print('❌ Download failed: $e');
      _errorMessage = 'Download failed: $e';
      notifyListeners();
    }
  }

  Future<bool> isCurrentTrackDownloaded() async {
    if (_currentTrack == null) return false;
    return await DownloadService().isDownloaded(_currentTrack!);
  }

  Stream<Map<String, double>> get downloadProgressStream => 
      DownloadService().downloadProgressStream;

  @override
  void dispose() {
    _windowsSmtcTimer?.cancel();
    _audioPlayer.dispose();
    if (Platform.isWindows) {
      WindowsMediaService.instance.dispose();
    }
    super.dispose();
  }
}
