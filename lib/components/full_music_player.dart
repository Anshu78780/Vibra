import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../controllers/music_player_controller.dart';
import '../components/universal_loader.dart';
import '../services/liked_songs_service.dart';
import '../services/user_playlist_service.dart';
import '../services/liked_playlists_service.dart';
import '../services/queue_playlist_service.dart';
import '../services/music_network_client.dart';
import '../services/lyrics_service.dart';
import '../models/music_model.dart';
import '../models/lyrics_model.dart';

class FullMusicPlayer extends StatefulWidget {
  const FullMusicPlayer({super.key});

  @override
  State<FullMusicPlayer> createState() => _FullMusicPlayerState();
}

class _FullMusicPlayerState extends State<FullMusicPlayer> with TickerProviderStateMixin {
  final MusicPlayerController _controller = MusicPlayerController();
  bool _isLiked = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  bool _showQueue = false;
  bool _showLyrics = false;
  bool _isLoadingLyrics = false;
  LyricsData? _lyricsData;
  String? _lastTrackForLyrics;
  late AnimationController _queueAnimationController;
  late Animation<double> _queueSlideAnimation;
  ScrollController? _lyricsScrollController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPlayerStateChanged);
    _checkIfLiked();
    _checkIfDownloaded();
    _initializeServices();
    
    // Initialize scroll controller for lyrics
    _lyricsScrollController = ScrollController();
    
    // Initialize queue animation
    _queueAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _queueSlideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _queueAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeServices() async {
    await QueuePlaylistService.loadQueuePlaylists();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChanged);
    _queueAnimationController.dispose();
    _lyricsScrollController?.dispose();
    super.dispose();
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {});
      _checkIfLiked();
      _checkIfDownloaded();
      _loadLyricsIfNeeded();
    }
  }

  void _loadLyricsIfNeeded() async {
    final currentTrack = _controller.currentTrack;
    if (currentTrack == null) {
      _lyricsData = null;
      _lastTrackForLyrics = null;
      return;
    }

    // Check if we already loaded lyrics for this track
    final trackKey = '${currentTrack.title}_${currentTrack.artist}';
    if (_lastTrackForLyrics == trackKey && _lyricsData != null) {
      return;
    }

    // Load lyrics for the new track
    if (!_isLoadingLyrics) {
      setState(() {
        _isLoadingLyrics = true;
        _lyricsData = null;
      });

      try {
        // Debug the track information being passed
        print('🎵 FULL_MUSIC_PLAYER: Loading lyrics for track');
        LyricsService.debugTrackInfo(currentTrack.title, currentTrack.artist);
        
        // Get track duration from the controller
        final trackDuration = _controller.duration.inSeconds.toDouble();
        
        final lyrics = await LyricsService.getLyrics(
          currentTrack.title,
          currentTrack.artist,
          duration: trackDuration > 0 ? trackDuration : null,
        );
        
        if (mounted) {
          setState(() {
            _lyricsData = lyrics;
            _lastTrackForLyrics = trackKey;
            _isLoadingLyrics = false;
          });
          
          // Reset scroll position for new lyrics
          if (_lyricsScrollController?.hasClients == true) {
            _lyricsScrollController!.jumpTo(0);
          }
          
          if (lyrics != null) {
            print('✅ FULL_MUSIC_PLAYER: Lyrics loaded successfully');
          } else {
            print('❌ FULL_MUSIC_PLAYER: No lyrics found');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _lyricsData = null;
            _lastTrackForLyrics = trackKey;
            _isLoadingLyrics = false;
          });
        }
        print('Error loading lyrics: $e');
      }
    }
  }

  void _checkIfLiked() {
    if (_controller.currentTrack != null) {
      final isLiked = LikedSongsService.isTrackLiked(_controller.currentTrack!.webpageUrl);
      if (isLiked != _isLiked) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    }
  }

  void _toggleLike() async {
    if (_controller.currentTrack != null) {
      final isLiked = await LikedSongsService.toggleLikedSong(_controller.currentTrack!);
      setState(() {
        _isLiked = isLiked;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLiked ? 'Added to liked songs' : 'Removed from liked songs',
            style: const TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _checkIfDownloaded() async {
    if (_controller.currentTrack != null) {
      final isDownloaded = await _controller.isCurrentTrackDownloaded();
      if (isDownloaded != _isDownloaded && mounted) {
        setState(() {
          _isDownloaded = isDownloaded;
        });
      }
    }
  }

  void _downloadTrack() async {
    // Check if running on Windows
    if (Platform.isWindows) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Download feature coming soon on Windows. Use Android to download tracks.',
              style: TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: Color(0xFF1C1C1E),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (_controller.currentTrack != null && !_isDownloading) {
      // Set immediate loading state
      setState(() {
        _isDownloading = true;
      });

      try {
        await _controller.downloadCurrentTrack();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Platform.isAndroid 
                    ? 'Download started - saving to Downloads/Vibra/${_controller.currentTrack!.title}.mp3'
                    : 'Download started - check notifications for progress',
                style: const TextStyle(fontFamily: 'CascadiaCode'),
              ),
              backgroundColor: const Color(0xFF1C1C1E),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          // Reset loading state after a short delay
          // The actual download progress will be handled by the download service
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isDownloading = false;
              });
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
          
          // Show different error messages based on the error type
          String errorMessage = 'Download failed: $e';
          if (e.toString().contains('permission')) {
            errorMessage = 'Storage permission required. Please grant permission in Settings.';
          } else if (e.toString().contains('already downloaded')) {
            errorMessage = 'Track already downloaded';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                style: const TextStyle(fontFamily: 'CascadiaCode'),
              ),
              backgroundColor: e.toString().contains('already downloaded') 
                  ? const Color(0xFF1C1C1E) 
                  : Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showQueueView() {
    setState(() {
      _showQueue = true;
    });
    _queueAnimationController.forward();
  }

  void _hideQueueView() {
    _queueAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showQueue = false;
        });
      }
    });
  }

  void _showShareDrawer() {
    final networkClient = MusicNetworkClient();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                const Icon(Icons.share_rounded, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share with ${networkClient.connectedDevice?.name ?? "Remote Device"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'CascadiaCode',
                        ),
                      ),
                      Text(
                        'Send music to connected device',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontFamily: 'CascadiaCode',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Share options
            if (_controller.currentTrack != null) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.orange),
                ),
                title: const Text(
                  'Send Current Track',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                subtitle: Text(
                  'Play "${_controller.currentTrack!.title}" on remote device',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontFamily: 'CascadiaCode',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _sendCurrentTrackToRemote();
                },
              ),
              const SizedBox(height: 8),
            ],
            if (_controller.queue.isNotEmpty) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.playlist_play_rounded, color: Colors.orange),
                ),
                title: const Text(
                  'Send Queue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                subtitle: Text(
                  'Send all ${_controller.queue.length} tracks to remote device',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _sendQueueToRemote();
                },
              ),
              const SizedBox(height: 8),
            ],
            // View Queue option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.queue_music_rounded, color: Colors.white),
              ),
              title: const Text(
                'View Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              subtitle: Text(
                'Manage your local queue (${_controller.queue.length} tracks)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showQueueView();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistManagement() {
    if (_controller.currentTrack == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _buildPlaylistManagementSheet(scrollController),
      ),
    );
  }

  Widget _buildPlaylistManagementSheet(ScrollController scrollController) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _controller.currentTrack!.thumbnail.isNotEmpty
                        ? Image.network(
                            _controller.currentTrack!.thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF2A2A2E),
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Color(0xFF666666),
                                  size: 24,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFF2A2A2E),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Color(0xFF666666),
                              size: 24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add to Playlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'CascadiaCode',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _controller.currentTrack!.title,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontFamily: 'CascadiaCode',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Playlists list
          Expanded(
            child: FutureBuilder<List<UserPlaylist>>(
              future: _loadUserPlaylists(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.withOpacity(0.7),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading playlists',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final playlists = snapshot.data ?? [];
                
                if (playlists.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_add_rounded,
                          color: Colors.grey.withOpacity(0.5),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No playlists found',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create playlists in the Liked Songs tab',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return FutureBuilder<bool>(
                      future: UserPlaylistService.isSongInPlaylist(
                        playlist.playlistId, 
                        _controller.currentTrack!.webpageUrl
                      ),
                      builder: (context, songSnapshot) {
                        final isInPlaylist = songSnapshot.data ?? false;
                        final isLoading = songSnapshot.connectionState == ConnectionState.waiting;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2E).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: isInPlaylist 
                                ? Border.all(color: const Color(0xFF6366F1), width: 1)
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3A3A3E),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.queue_music_rounded,
                                color: isInPlaylist ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.7),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              playlist.name,
                              style: TextStyle(
                                color: isInPlaylist ? const Color(0xFF6366F1) : Colors.white,
                                fontSize: 16,
                                fontWeight: isInPlaylist ? FontWeight.w600 : FontWeight.w500,
                                fontFamily: 'CascadiaCode',
                              ),
                            ),
                            subtitle: FutureBuilder<List<MusicTrack>>(
                              future: UserPlaylistService.getPlaylistSongs(playlist.playlistId),
                              builder: (context, songsSnapshot) {
                                final songsCount = songsSnapshot.data?.length ?? 0;
                                return Text(
                                  '$songsCount songs',
                                  style: TextStyle(
                                    color: isInPlaylist 
                                        ? const Color(0xFF6366F1).withOpacity(0.8)
                                        : Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                    fontFamily: 'CascadiaCode',
                                  ),
                                );
                              },
                            ),
                            trailing: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                    ),
                                  )
                                : Icon(
                                    isInPlaylist ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                    color: isInPlaylist ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.7),
                                  ),
                            onTap: isLoading ? null : () => _toggleSongInPlaylist(playlist, isInPlaylist),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<UserPlaylist>> _loadUserPlaylists() async {
    await UserPlaylistService.loadCachedPlaylists();
    return UserPlaylistService.getUserPlaylists();
  }

  void _toggleSongInPlaylist(UserPlaylist playlist, bool isCurrentlyInPlaylist) async {
    if (_controller.currentTrack == null) return;
    
    final song = _controller.currentTrack!;
    bool success = false;
    String message = '';
    
    try {
      if (isCurrentlyInPlaylist) {
        // Remove from playlist
        success = await UserPlaylistService.removeSongFromPlaylist(
          playlist.playlistId, 
          song.webpageUrl
        );
        message = success 
            ? 'Removed from "${playlist.name}"'
            : 'Failed to remove from playlist';
      } else {
        // Add to playlist
        success = await UserPlaylistService.addSongToPlaylist(playlist.playlistId, song);
        message = success 
            ? 'Added to "${playlist.name}"'
            : (await UserPlaylistService.isSongInPlaylist(playlist.playlistId, song.webpageUrl))
                ? 'Song already in playlist'
                : 'Failed to add to playlist';
      }
      
      if (mounted) {
        // Close the bottom sheet
        Navigator.pop(context);
        
        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: success ? const Color(0xFF1C1C1E) : Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'Now Playing',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'CascadiaCode',
                fontSize: 16,
              ),
            ),
            if (_controller.queue.isNotEmpty)
              Text(
                '${_controller.currentIndex + 1} of ${_controller.queue.length}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'CascadiaCode',
                  fontSize: 12,
                ),
              ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showOptions(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          
          return Stack(
            children: [
              _controller.hasTrack ? _buildPlayerContent() : _buildNoTrackContent(),
              // Only show queue overlay on mobile
              if (!isDesktop && _showQueue) _buildQueueOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoTrackContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: Color(0xFF666666),
          ),
          SizedBox(height: 16),
          Text(
            'No track playing',
            style: TextStyle(
              color: Color(0xFF999999),
              fontSize: 16,
              fontFamily: 'CascadiaCode',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            const Color(0xFF1A1A1A),
            Colors.black,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            
            if (isDesktop) {
              return _buildDesktopLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         kToolbarHeight - 
                         MediaQuery.of(context).padding.top,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Album artwork (smaller when showing lyrics)
                  _showLyrics ? _buildCompactAlbumArtwork() : _buildAlbumArtwork(),
                  const SizedBox(height: 20),
                  // Track info
                  _buildTrackInfo(),
                  const SizedBox(height: 20),
                  // Lyrics/Controls toggle button
                  _buildLyricsToggleButton(),
                  const SizedBox(height: 20),
                  // Show either lyrics or controls
                  if (_showLyrics)
                    _buildLyricsView()
                  else
                    _buildControlsSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        // Error message overlay
        if (_controller.errorMessage != null) 
          Positioned.fill(child: _buildErrorMessage()),
        // Loading overlay
        if (_controller.isLoading) 
          Positioned.fill(child: _buildLoadingOverlay()),
      ],
    );
  }

  Widget _buildLyricsToggleButton() {
    if (_controller.currentTrack == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showLyrics = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_showLyrics 
                      ? const Color(0xFF6366F1) 
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: const Color(0xFF6366F1),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Controls',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_showLyrics ? Colors.white : const Color(0xFF6366F1),
                    fontFamily: 'CascadiaCode',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showLyrics = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _showLyrics 
                      ? const Color(0xFF6366F1) 
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: const Color(0xFF6366F1),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Lyrics',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _showLyrics ? Colors.white : const Color(0xFF6366F1),
                    fontFamily: 'CascadiaCode',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Column(
      children: [
        // Progress bar
        _buildProgressBar(),
        const SizedBox(height: 32),
        // Controls
        _buildControls(),
        const SizedBox(height: 24),
        // Action buttons (like, download, queue)
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildLyricsView() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      child: _buildLyricsContent(),
    );
  }

  Widget _buildLyricsContent() {
    if (_isLoadingLyrics) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading lyrics...',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ],
        ),
      );
    }

    if (_lyricsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No lyrics available',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontFamily: 'CascadiaCode',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lyrics not found for this track',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ],
        ),
      );
    }

    if (_lyricsData!.hasSyncedLyrics) {
      return _buildSyncedLyrics();
    } else if (_lyricsData!.hasPlainLyrics) {
      return _buildPlainLyrics();
    } else {
      return const Center(
        child: Text(
          'No lyrics available',
          style: TextStyle(
            color: Colors.grey,
            fontFamily: 'CascadiaCode',
          ),
        ),
      );
    }
  }

  Widget _buildSyncedLyrics() {
    final currentPosition = _controller.position.inSeconds.toDouble();
    final lyrics = _lyricsData!.lyrics;
    
    // Find the current line index
    int currentLineIndex = -1;
    for (int i = 0; i < lyrics.length; i++) {
      if (_isCurrentLyricsLine(lyrics[i], currentPosition, i)) {
        currentLineIndex = i;
        break;
      }
    }
    
    // Auto-scroll to current line (keep it near the top like Spotify)
    if (currentLineIndex >= 0 && _lyricsScrollController?.hasClients == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_lyricsScrollController?.hasClients == true) {
          // Calculate offset to keep current line at 1/3 from top (like Spotify)
          final itemHeight = 56.0; // Approximate height per line
          final viewportHeight = _lyricsScrollController!.position.viewportDimension;
          final targetOffset = (currentLineIndex * itemHeight) - (viewportHeight * 0.3);
          
          _lyricsScrollController!.animateTo(
            targetOffset.clamp(0.0, _lyricsScrollController!.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    
    return ListView.builder(
      controller: _lyricsScrollController,
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: lyrics.length,
      itemBuilder: (context, index) {
        final line = lyrics[index];
        final isCurrentLine = _isCurrentLyricsLine(line, currentPosition, index);
        final isUpcomingLine = _isUpcomingLyricsLine(line, currentPosition);
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          child: Text(
            line.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCurrentLine ? 24 : 18,
              fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
              color: isCurrentLine 
                  ? const Color(0xFF6366F1)
                  : isUpcomingLine 
                      ? Colors.white.withOpacity(0.8)
                      : Colors.white.withOpacity(0.4),
              fontFamily: 'CascadiaCode',
              height: 1.4,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlainLyrics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(
        _lyricsData!.metadata.plainLyrics,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontFamily: 'CascadiaCode',
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  bool _isCurrentLyricsLine(LyricsLine line, double currentPosition, int index) {
    if (index >= _lyricsData!.lyrics.length - 1) {
      // Last line
      return currentPosition >= line.startTime;
    }
    
    final nextLine = _lyricsData!.lyrics[index + 1];
    return currentPosition >= line.startTime && currentPosition < nextLine.startTime;
  }

  bool _isUpcomingLyricsLine(LyricsLine line, double currentPosition) {
    return line.startTime > currentPosition && line.startTime <= currentPosition + 10;
  }

  Widget _buildDesktopLayout() {
    return Stack(
      children: [
        Row(
      children: [
        // Left side - Player controls
        Expanded(
          flex: 3,
          child: Container(
            height: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
            padding: const EdgeInsets.all(32.0),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top - 64,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compact album artwork
                    _buildCompactAlbumArtwork(),
                    const SizedBox(height: 20),
                    // Track info
                    _buildDesktopTrackInfo(),
                    const SizedBox(height: 20),
                    // Progress bar
                    _buildProgressBar(),
                    const SizedBox(height: 20),
                    // Enhanced desktop controls
                    _buildDesktopControls(),
                    const SizedBox(height: 16),
                    // Action buttons
                    _buildDesktopActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Vertical divider
        Container(
          width: 1,
          color: const Color(0xFF333333),
        ),
        // Right side - Queue
        Expanded(
          flex: 2,
          child: _buildDesktopQueue(),
        ),
      ],
    ),
    // Error message overlay
    if (_controller.errorMessage != null) 
      Positioned.fill(child: _buildErrorMessage()),
    // Loading overlay
    if (_controller.isLoading) 
      Positioned.fill(child: _buildLoadingOverlay()),
    ],
  );
}

  Widget _buildAlbumArtwork() {
    final screenWidth = MediaQuery.of(context).size.width;
    final artworkSize = (screenWidth * 0.8).clamp(280.0, 320.0);
    
    return Container(
      width: artworkSize,
      height: artworkSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.transparent,
              Colors.black.withOpacity(0.1),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: _controller.currentTrack!.thumbnail.isNotEmpty
              ? Image.network(
                  _controller.currentTrack!.thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF2A2A2E),
                            const Color(0xFF1C1C1E),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Color(0xFF666666),
                        size: 120,
                      ),
                    );
                  },
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2A2A2E),
                        const Color(0xFF1C1C1E),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFF666666),
                    size: 120,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _controller.currentTrack!.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFamily: 'CascadiaCode',
              letterSpacing: 0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _controller.currentTrack!.artist,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'CascadiaCode',
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCompactAlbumArtwork() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 3,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _controller.currentTrack!.thumbnail.isNotEmpty
            ? Image.network(
                _controller.currentTrack!.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2A2A2E),
                          const Color(0xFF1C1C1E),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFF666666),
                      size: 70,
                    ),
                  );
                },
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2A2A2E),
                      const Color(0xFF1C1C1E),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Color(0xFF666666),
                  size: 70,
                ),
              ),
      ),
    );
  }

  Widget _buildDesktopTrackInfo() {
    return Column(
      children: [
        Text(
          _controller.currentTrack!.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'CascadiaCode',
            letterSpacing: 0.5,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          _controller.currentTrack!.artist,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'CascadiaCode',
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        // Queue position indicator
        if (_controller.queue.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2E).withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3A3A3E),
                width: 1,
              ),
            ),
            child: Text(
              'Track ${_controller.currentIndex + 1} of ${_controller.queue.length}',
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 11,
                fontFamily: 'CascadiaCode',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopControls() {
    return Column(
      children: [
        // Main controls row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDesktopControlButton(
              icon: Icons.skip_previous_rounded,
              size: 28,
              isEnabled: _controller.hasPrevious && _controller.canControl,
              onPressed: _controller.hasPrevious && _controller.canControl
                  ? () => _controller.playPrevious()
                  : null,
            ),
            const SizedBox(width: 16),
            // Enhanced play/pause button
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFDC2626),
                    Color(0xFF6366F1),
                    Color(0xFF991B1B),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  _controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                iconSize: 28,
                onPressed: _controller.canControl
                    ? () {
                        if (_controller.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.resume();
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            _buildDesktopControlButton(
              icon: Icons.skip_next_rounded,
              size: 28,
              isEnabled: _controller.hasNext && _controller.canControl,
              onPressed: _controller.hasNext && _controller.canControl
                  ? () => _controller.playNext()
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopControlButton({
    required IconData icon,
    required double size,
    required bool isEnabled,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2E).withOpacity(0.8),
        shape: BoxShape.circle,
        border: Border.all(
          color: isEnabled 
              ? const Color(0xFF3A3A3E) 
              : const Color(0xFF2A2A2A),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isEnabled ? Colors.white : Colors.white38,
        ),
        iconSize: size,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildDesktopActionButtons() {
    final networkClient = MusicNetworkClient();
    final isConnected = networkClient.isConnected;
    
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      runAlignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildCompactActionButton(
          icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: _isLiked ? 'Liked' : 'Like',
          color: _isLiked ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.8),
          onTap: _toggleLike,
        ),
        _buildCompactActionButton(
          icon: _isDownloading 
              ? Icons.downloading // Use a different icon for loading state
              : (Platform.isWindows 
                  ? Icons.download_outlined 
                  : (_isDownloaded ? Icons.download_done_rounded : Icons.download_rounded)),
          label: _isDownloading 
              ? 'Starting...'
              : (Platform.isWindows 
                  ? 'Coming Soon' 
                  : (_isDownloaded ? 'Downloaded' : 'Download')),
          color: _isDownloading
              ? const Color(0xFF6366F1)
              : (Platform.isWindows 
                  ? Colors.grey.withOpacity(0.6) 
                  : (_isDownloaded ? Colors.green : Colors.white.withOpacity(0.8))),
          onTap: _isDownloading ? null : _downloadTrack,
          isLoading: _isDownloading,
        ),
        _buildCompactActionButton(
          icon: Icons.playlist_add_rounded,
          label: 'Playlists',
          color: Colors.white.withOpacity(0.8),
          onTap: _showPlaylistManagement,
        ),
        if (isConnected && _controller.currentTrack != null)
          _buildCompactActionButton(
            icon: Icons.send_rounded,
            label: 'Send Track',
            color: Colors.orange,
            onTap: _sendCurrentTrackToRemote,
          ),
        if (isConnected && _controller.queue.isNotEmpty)
          _buildCompactActionButton(
            icon: Icons.playlist_play_rounded,
            label: 'Send Queue',
            color: Colors.orange,
            onTap: _sendQueueToRemote,
          ),
      ],
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          constraints: const BoxConstraints(
            minHeight: 44,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3A3A3E),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                )
              else
                Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopQueue() {
    return Container(
      height: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
      ),
      child: Column(
        children: [
          // Queue header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF333333), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Playing Queue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'CascadiaCode',
                        ),
                      ),
                      Text(
                        '${_controller.queue.length} tracks',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontFamily: 'CascadiaCode',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_controller.queue.length > 1)
                  IconButton(
                    onPressed: () => _saveQueueAsPlaylist(),
                    icon: const Icon(
                      Icons.favorite_border_rounded,
                      color: Color(0xFF6366F1),
                    ),
                    tooltip: 'Save queue as playlist',
                  ),
                IconButton(
                  onPressed: () {
                    _showOptions();
                  },
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          // Queue list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _controller.queue.length,
              itemBuilder: (context, index) {
                final track = _controller.queue[index];
                final isCurrentTrack = index == _controller.currentIndex;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isCurrentTrack 
                        ? const Color(0xFF6366F1).withOpacity(0.2)
                        : const Color(0xFF2A2A2E).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: isCurrentTrack 
                        ? Border.all(color: const Color(0xFF6366F1), width: 1)
                        : null,
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: track.thumbnail.isNotEmpty
                            ? Image.network(
                                track.thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFF3A3A3E),
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      color: Color(0xFF666666),
                                      size: 20,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: const Color(0xFF3A3A3E),
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Color(0xFF666666),
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                    title: Text(
                      track.title,
                      style: TextStyle(
                        color: isCurrentTrack ? const Color(0xFF6366F1) : Colors.white,
                        fontSize: 14,
                        fontWeight: isCurrentTrack ? FontWeight.w600 : FontWeight.w500,
                        fontFamily: 'CascadiaCode',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.artist,
                      style: TextStyle(
                        color: isCurrentTrack 
                            ? const Color(0xFF6366F1).withOpacity(0.8)
                            : Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontFamily: 'CascadiaCode',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrentTrack
                        ? Icon(
                            _controller.isPlaying 
                                ? Icons.volume_up_rounded 
                                : Icons.pause_rounded,
                            color: const Color(0xFF6366F1),
                            size: 16,
                          )
                        : null,
                    onTap: () {
                      if (!isCurrentTrack) {
                        _controller.playTrackFromQueue(_controller.queue, index);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _controller.canControl ? const Color(0xFF6366F1) : const Color(0xFF666666),
            inactiveTrackColor: const Color(0xFF333333),
            thumbColor: _controller.canControl ? const Color(0xFF6366F1) : const Color(0xFF666666),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            trackHeight: 4,
            disabledActiveTrackColor: const Color(0xFF666666),
            disabledInactiveTrackColor: const Color(0xFF333333),
            disabledThumbColor: const Color(0xFF666666),
          ),
          child: Slider(
            value: _controller.progress.clamp(0.0, 1.0),
            onChanged: _controller.canControl && _controller.duration > Duration.zero ? (value) {
              final position = Duration(
                milliseconds: (value * _controller.duration.inMilliseconds).round(),
              );
              _controller.seek(position);
            } : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _controller.formattedPosition,
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 14,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              Text(
                _controller.formattedDuration,
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 14,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.skip_previous_rounded,
            size: 52,
            isEnabled: _controller.hasPrevious && _controller.canControl,
            onPressed: _controller.hasPrevious && _controller.canControl
                ? () => _controller.playPrevious()
                : null,
          ),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFDC2626),
                  Color(0xFF6366F1),
                  Color(0xFF991B1B),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              iconSize: 44,
              onPressed: _controller.canControl
                  ? () {
                      if (_controller.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.resume();
                      }
                    }
                  : null,
            ),
          ),
          _buildControlButton(
            icon: Icons.skip_next_rounded,
            size: 52,
            isEnabled: _controller.hasNext && _controller.canControl,
            onPressed: _controller.hasNext && _controller.canControl
                ? () => _controller.playNext()
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required bool isEnabled,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2E).withOpacity(0.8),
        shape: BoxShape.circle,
        border: Border.all(
          color: isEnabled 
              ? const Color(0xFF3A3A3E) 
              : const Color(0xFF2A2A2A),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isEnabled ? Colors.white : Colors.white38,
        ),
        iconSize: size,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildActionButtons() {
    final networkClient = MusicNetworkClient();
    final isConnected = networkClient.isConnected;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _buildActionButton(
            icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: _isLiked ? 'Liked' : 'Like',
            color: _isLiked ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.8),
            onTap: _toggleLike,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildActionButton(
            icon: _isDownloading 
                ? Icons.downloading // Use a different icon for loading state
                : (Platform.isWindows 
                    ? Icons.download_outlined 
                    : (_isDownloaded ? Icons.download_done_rounded : Icons.download_rounded)),
            label: _isDownloading 
                ? 'Starting...'
                : (Platform.isWindows 
                    ? 'Coming Soon' 
                    : (_isDownloaded ? 'Downloaded' : 'Download')),
            color: _isDownloading
                ? const Color(0xFF6366F1)
                : (Platform.isWindows 
                    ? Colors.grey.withOpacity(0.6) 
                    : (_isDownloaded ? Colors.green : Colors.white.withOpacity(0.8))),
            onTap: _isDownloading ? null : _downloadTrack,
            isLoading: _isDownloading,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildActionButton(
            icon: Icons.playlist_add_rounded,
            label: 'Playlists',
            color: Colors.white.withOpacity(0.8),
            onTap: _showPlaylistManagement,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildActionButton(
            icon: isConnected ? Icons.share_rounded : Icons.queue_music_rounded,
            label: isConnected ? 'Share with' : 'Queue',
            color: isConnected ? Colors.orange : Colors.white.withOpacity(0.8),
            onTap: isConnected ? _showShareDrawer : _showQueueView,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          constraints: const BoxConstraints(
            minHeight: 50,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                )
              else
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'CascadiaCode',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueOverlay() {
    return AnimatedBuilder(
      animation: _queueSlideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, MediaQuery.of(context).size.height * 0.7 * _queueSlideAnimation.value),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.3),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Queue header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _hideQueueView,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Queue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'CascadiaCode',
                              ),
                            ),
                            Text(
                              '${_controller.queue.length} songs',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontFamily: 'CascadiaCode',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_controller.queue.length > 1)
                        IconButton(
                          onPressed: () {
                            _hideQueueView();
                            _saveQueueAsPlaylist();
                          },
                          icon: const Icon(
                            Icons.favorite_border_rounded,
                            color: Color(0xFF6366F1),
                          ),
                          tooltip: 'Save queue as playlist',
                        ),
                      IconButton(
                        onPressed: () {
                          // TODO: Add queue options (clear, shuffle, etc.)
                        },
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Queue list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _controller.queue.length,
                    itemBuilder: (context, index) {
                      final track = _controller.queue[index];
                      final isCurrentTrack = index == _controller.currentIndex;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isCurrentTrack 
                              ? const Color(0xFF6366F1).withOpacity(0.2)
                              : const Color(0xFF2A2A2E).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrentTrack 
                              ? Border.all(color: const Color(0xFF6366F1), width: 1)
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: track.thumbnail.isNotEmpty
                                  ? Image.network(
                                      track.thumbnail,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: const Color(0xFF3A3A3E),
                                          child: const Icon(
                                            Icons.music_note_rounded,
                                            color: Color(0xFF666666),
                                            size: 24,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: const Color(0xFF3A3A3E),
                                      child: const Icon(
                                        Icons.music_note_rounded,
                                        color: Color(0xFF666666),
                                        size: 24,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            track.title,
                            style: TextStyle(
                              color: isCurrentTrack ? const Color(0xFF6366F1) : Colors.white,
                              fontSize: 16,
                              fontWeight: isCurrentTrack ? FontWeight.w600 : FontWeight.w500,
                              fontFamily: 'CascadiaCode',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artist,
                            style: TextStyle(
                              color: isCurrentTrack 
                                  ? const Color(0xFF6366F1).withOpacity(0.8)
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontFamily: 'CascadiaCode',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrentTrack)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _controller.isPlaying 
                                            ? Icons.volume_up_rounded 
                                            : Icons.pause_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Now Playing',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'CascadiaCode',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            if (!isCurrentTrack) {
                              _controller.playTrackFromQueue(_controller.queue, index);
                            }
                            _hideQueueView();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: UniversalLoader(
        message: _controller.loadingMessage,
        size: 50,
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Playback Error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'CascadiaCode',
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _controller.errorMessage!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: 'CascadiaCode',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            
            // Check if this is a video unavailable error to show alternative search option
            if (_controller.errorMessage!.contains('This video is not available') ||
                _controller.errorMessage!.contains('VideoUnplayableException') ||
                _controller.errorMessage!.contains('Streams are not available'))
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _controller.searchAlternativeTrack(),
                    icon: const Icon(Icons.search, color: Colors.white),
                    label: const Text(
                      'Find Alternative',
                      style: TextStyle(
                        fontFamily: 'CascadiaCode',
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _controller.retry(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Retry Original',
                      style: TextStyle(fontFamily: 'CascadiaCode'),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: () => _controller.retry(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontFamily: 'CascadiaCode'),
                ),
              ),
            
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _controller.clearError(),
              child: const Text(
                'Dismiss',
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendCurrentTrackToRemote() async {
    if (_controller.currentTrack == null) return;
    
    final networkClient = MusicNetworkClient();
    if (!networkClient.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected to any device'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await networkClient.remotePlayTrack(_controller.currentTrack!);
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success 
            ? 'Playing "${_controller.currentTrack!.title}" on ${networkClient.connectedDevice?.name}'
            : 'Failed to play track on remote device'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _sendQueueToRemote() async {
    if (_controller.queue.isEmpty) return;
    
    final networkClient = MusicNetworkClient();
    if (!networkClient.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected to any device'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show dialog to select how to send
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Send Queue',
          style: TextStyle(color: Colors.white, fontFamily: 'CascadiaCode'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send ${_controller.queue.length} tracks to ${networkClient.connectedDevice?.name}?',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose how to send:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'replace'),
            child: const Text('Replace Queue', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'add'),
            child: const Text('Add to Queue', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (result == null) return;

    bool success = false;
    if (result == 'replace') {
      // Calculate start index based on current track
      final startIndex = _controller.currentIndex >= 0 ? _controller.currentIndex : 0;
      success = await networkClient.remotePlayPlaylist(_controller.queue, 
          startIndex: startIndex, replaceQueue: true);
    } else if (result == 'add') {
      success = await networkClient.remoteAddToQueue(_controller.queue);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success 
            ? 'Sent ${_controller.queue.length} tracks to remote device'
            : 'Failed to send queue to remote device'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.queue_music_rounded, color: Colors.white),
              ),
              title: const Text(
                'View Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                '${_controller.queue.length} songs',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'CascadiaCode',
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showQueueView();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.playlist_add_rounded, color: Colors.white),
              ),
              title: const Text(
                'Add to Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Manage playlist membership',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'CascadiaCode',
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showPlaylistManagement();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.stop_rounded, color: Colors.white),
              ),
              title: const Text(
                'Stop Playing',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Stop and clear queue',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'CascadiaCode',
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _controller.stop();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveQueueAsPlaylist() async {
    if (_controller.queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No songs in queue to save',
            style: TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show dialog to get playlist name
    final playlistName = await _showPlaylistNameDialog();
    if (playlistName == null || playlistName.trim().isEmpty) {
      return;
    }

    try {
      // Get the first track's thumbnail for the playlist thumbnail
      final thumbnailUrl = _controller.queue.isNotEmpty 
          ? _controller.queue.first.thumbnail 
          : '';
      
      // Save the queue playlist with actual songs
      final playlistId = await QueuePlaylistService.saveQueueAsPlaylist(
        name: playlistName.trim(),
        songs: _controller.queue,
        thumbnailUrl: thumbnailUrl,
      );
      
      // Create a custom playlist description
      final artistsSet = _controller.queue
          .map((track) => track.artist)
          .where((artist) => artist.isNotEmpty)
          .toSet();
      
      final description = artistsSet.isEmpty 
          ? 'Generated from music queue'
          : 'Artists: ${artistsSet.take(3).join(', ')}${artistsSet.length > 3 ? '...' : ''}';

      // Add to liked playlists for display in liked section
      await LikedPlaylistsService.togglePlaylistLike(
        playlistId: playlistId,
        title: playlistName.trim(),
        channelName: description,
        playlistUrl: '', // No URL for generated queue
        thumbnailUrl: thumbnailUrl,
        source: 'queue',
      );

      if (mounted) {
        // Temporarily update the UI to show success
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Saved "${playlistName.trim()}" with ${_controller.queue.length} songs to liked playlists',
                    style: const TextStyle(fontFamily: 'CascadiaCode'),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1C1C1E),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save queue as playlist: $e',
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String?> _showPlaylistNameDialog() async {
    String? playlistName;
    
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Save Queue as Liked Playlist',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'CascadiaCode',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter a name for your playlist containing ${_controller.queue.length} songs:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontFamily: 'CascadiaCode',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
                ),
                decoration: InputDecoration(
                  hintText: 'My Queue Mix ${DateTime.now().day}/${DateTime.now().month}',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontFamily: 'CascadiaCode',
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  playlistName = value;
                },
                onSubmitted: (value) {
                  Navigator.of(context).pop(value.trim().isNotEmpty ? value.trim() : null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(playlistName?.trim().isNotEmpty == true ? playlistName!.trim() : null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
