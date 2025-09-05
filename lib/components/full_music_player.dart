import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';
import '../components/universal_loader.dart';
import '../services/liked_songs_service.dart';

class FullMusicPlayer extends StatefulWidget {
  const FullMusicPlayer({super.key});

  @override
  State<FullMusicPlayer> createState() => _FullMusicPlayerState();
}

class _FullMusicPlayerState extends State<FullMusicPlayer> {
  final MusicPlayerController _controller = MusicPlayerController();
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPlayerStateChanged);
    _checkIfLiked();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChanged);
    super.dispose();
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {});
      _checkIfLiked();
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
      body: _controller.hasTrack ? _buildPlayerContent() : _buildNoTrackContent(),
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Spacer(),
          // Album artwork
          _buildAlbumArtwork(),
          const SizedBox(height: 32),
          // Track info
          _buildTrackInfo(),
          const SizedBox(height: 32),
          // Progress bar
          _buildProgressBar(),
          const SizedBox(height: 32),
          // Controls
          _buildControls(),
          const Spacer(),
          // Error message
          if (_controller.errorMessage != null) _buildErrorMessage(),
          // Loading overlay
          if (_controller.isLoading) _buildLoadingOverlay(),
          // Error message
          if (_controller.errorMessage != null) _buildErrorMessage(),
        ],
      ),
    );
  }

  Widget _buildAlbumArtwork() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                    color: const Color(0xFF1C1C1E),
                    child: const Icon(
                      Icons.music_note,
                      color: Color(0xFF666666),
                      size: 80,
                    ),
                  );
                },
              )
            : Container(
                color: const Color(0xFF1C1C1E),
                child: const Icon(
                  Icons.music_note,
                  color: Color(0xFF666666),
                  size: 80,
                ),
              ),
      ),
    );
  }

  Widget _buildTrackInfo() {
    return Column(
      children: [
        Text(
          _controller.currentTrack!.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          _controller.currentTrack!.artist,
          style: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 18,
            fontFamily: 'monospace',
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.skip_previous,
            color: _controller.hasPrevious && _controller.canControl 
                ? Colors.white 
                : Colors.white38,
          ),
          iconSize: 48,
          onPressed: _controller.hasPrevious && _controller.canControl
              ? () {
                  _controller.playPrevious();
                }
              : null,
        ),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFFB91C1C),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _controller.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            iconSize: 40,
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
        IconButton(
          icon: Icon(
            Icons.skip_next,
            color: _controller.hasNext && _controller.canControl 
                ? Colors.white 
                : Colors.white38,
          ),
          iconSize: 48,
          onPressed: _controller.hasNext && _controller.canControl
              ? () {
                  _controller.playNext();
                }
              : null,
        ),
      ],
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border, 
                color: _isLiked ? const Color(0xFFB91C1C) : Colors.white
              ),
              title: Text(
                _isLiked ? 'Unlike' : 'Like',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleLike();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text(
                'Share',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.stop, color: Colors.white),
              title: const Text(
                'Stop',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
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
