import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';
import '../components/universal_loader.dart';
import '../services/liked_songs_service.dart';

class FullMusicPlayer extends StatefulWidget {
  const FullMusicPlayer({super.key});

  @override
  State<FullMusicPlayer> createState() => _FullMusicPlayerState();
}

class _FullMusicPlayerState extends State<FullMusicPlayer> with TickerProviderStateMixin {
  final MusicPlayerController _controller = MusicPlayerController();
  bool _isLiked = false;
  bool _isDownloaded = false;
  bool _showQueue = false;
  late AnimationController _queueAnimationController;
  late Animation<double> _queueSlideAnimation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPlayerStateChanged);
    _checkIfLiked();
    _checkIfDownloaded();
    
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

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChanged);
    _queueAnimationController.dispose();
    super.dispose();
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {});
      _checkIfLiked();
      _checkIfDownloaded();
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
            style: const TextStyle(fontFamily: 'monospace'),
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
    if (_controller.currentTrack != null) {
      try {
        await _controller.downloadCurrentTrack();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Download started - check notifications for progress',
                style: TextStyle(fontFamily: 'monospace'),
              ),
              backgroundColor: Color(0xFF1C1C1E),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Download failed: $e',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              backgroundColor: const Color(0xFFB91C1C),
              duration: const Duration(seconds: 3),
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
                fontFamily: 'monospace',
                fontSize: 16,
              ),
            ),
            if (_controller.queue.isNotEmpty)
              Text(
                '${_controller.currentIndex + 1} of ${_controller.queue.length}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'monospace',
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
      body: Stack(
        children: [
          _controller.hasTrack ? _buildPlayerContent() : _buildNoTrackContent(),
          if (_showQueue) _buildQueueOverlay(),
        ],
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
              fontFamily: 'monospace',
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
        child: SingleChildScrollView(
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
                  // Album artwork
                  _buildAlbumArtwork(),
                  const SizedBox(height: 40),
                  // Track info
                  _buildTrackInfo(),
                  const SizedBox(height: 32),
                  // Progress bar
                  _buildProgressBar(),
                  const SizedBox(height: 32),
                  // Controls
                  _buildControls(),
                  const SizedBox(height: 24),
                  // Action buttons (like, download, queue)
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                  // Error message
                  if (_controller.errorMessage != null) _buildErrorMessage(),
                  // Loading overlay
                  if (_controller.isLoading) _buildLoadingOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
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
            color: const Color(0xFFB91C1C).withOpacity(0.3),
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
              fontFamily: 'monospace',
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
            fontFamily: 'monospace',
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _controller.canControl ? const Color(0xFFB91C1C) : const Color(0xFF666666),
            inactiveTrackColor: const Color(0xFF333333),
            thumbColor: _controller.canControl ? const Color(0xFFB91C1C) : const Color(0xFF666666),
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
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                _controller.formattedDuration,
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 14,
                  fontFamily: 'monospace',
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
                  Color(0xFFB91C1C),
                  Color(0xFF991B1B),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB91C1C).withOpacity(0.4),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: _isLiked ? 'Liked' : 'Like',
          color: _isLiked ? const Color(0xFFB91C1C) : Colors.white.withOpacity(0.8),
          onTap: _toggleLike,
        ),
        _buildActionButton(
          icon: _isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
          label: _isDownloaded ? 'Downloaded' : 'Download',
          color: _isDownloaded ? Colors.green : Colors.white.withOpacity(0.8),
          onTap: _isDownloaded ? null : _downloadTrack,
        ),
        _buildActionButton(
          icon: Icons.queue_music_rounded,
          label: 'Queue',
          color: Colors.white.withOpacity(0.8),
          onTap: _showQueueView,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
          ],
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
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              '${_controller.queue.length} songs',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
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
                              ? const Color(0xFFB91C1C).withOpacity(0.2)
                              : const Color(0xFF2A2A2E).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrentTrack 
                              ? Border.all(color: const Color(0xFFB91C1C), width: 1)
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
                              color: isCurrentTrack ? const Color(0xFFB91C1C) : Colors.white,
                              fontSize: 16,
                              fontWeight: isCurrentTrack ? FontWeight.w600 : FontWeight.w500,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artist,
                            style: TextStyle(
                              color: isCurrentTrack 
                                  ? const Color(0xFFB91C1C).withOpacity(0.8)
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontFamily: 'monospace',
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
                                    color: const Color(0xFFB91C1C),
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
                                          fontFamily: 'monospace',
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
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: UniversalLoader(
          message: _controller.loadingMessage,
          size: 50,
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Positioned.fill(
      child: Container(
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
                  fontFamily: 'monospace',
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
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _controller.retry(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
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
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                '${_controller.queue.length} songs',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'monospace',
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
                child: const Icon(Icons.stop_rounded, color: Colors.white),
              ),
              title: const Text(
                'Stop Playing',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Stop and clear queue',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'monospace',
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
}
