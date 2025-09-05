import 'package:flutter/material.dart';
import '../models/music_model.dart';
import '../controllers/music_player_controller.dart';
import '../services/liked_songs_service.dart';

class LikedSongsPage extends StatefulWidget {
  const LikedSongsPage({super.key});

  @override
  State<LikedSongsPage> createState() => _LikedSongsPageState();
}

class _LikedSongsPageState extends State<LikedSongsPage> {
  List<MusicTrack> _likedSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikedSongs();
  }

  Future<void> _loadLikedSongs() async {
    setState(() {
      _isLoading = true;
    });

    // Ensure cached songs are loaded
    await LikedSongsService.loadCachedLikedSongs();
    
    setState(() {
      _likedSongs = LikedSongsService.getLikedSongs();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Liked Songs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        titleSpacing: 16.0,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadLikedSongs,
        backgroundColor: const Color(0xFF1C1C1E),
        color: const Color(0xFFB91C1C),
        strokeWidth: 2.5,
        displacement: 40,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFB91C1C),
          strokeWidth: 3,
        ),
      );
    }

    if (_likedSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 72,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No liked songs yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your favorite songs will appear here',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _likedSongs.length,
      physics: const BouncingScrollPhysics(),
      cacheExtent: 1000,
      itemBuilder: (context, index) {
        final track = _likedSongs[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMusicTile(track),
            if (index < _likedSongs.length - 1)
              const Divider(
                color: Color(0xFF1A1A1A),
                height: 1,
                thickness: 0.5,
                indent: 88,
              ),
          ],
        );
      },
    );
  }

  Widget _buildMusicTile(MusicTrack track) {
    return GestureDetector(
      onTap: () => _playTrack(track),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // Album artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: track.thumbnail.isNotEmpty
                  ? Image.network(
                      track.thumbnail,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      cacheWidth: 112,
                      cacheHeight: 112,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFF1C1C1E),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB91C1C)),
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Color(0xFF666666),
                            size: 24,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Color(0xFF666666),
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Duration
            Text(
              track.durationString,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 16),
            // Unlike option
            GestureDetector(
              onTap: () => _unlikeSong(track),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFB91C1C),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playTrack(MusicTrack track) {
    final trackIndex = _likedSongs.indexWhere((t) => t.webpageUrl == track.webpageUrl);
    if (trackIndex != -1) {
      // Play the track and set up the entire queue
      MusicPlayerController().playTrackFromQueue(_likedSongs, trackIndex);
    } else {
      // Fallback to single track play
      MusicPlayerController().playTrack(track);
    }
  }

  void _unlikeSong(MusicTrack track) async {
    await LikedSongsService.removeLikedSong(track.webpageUrl);
    setState(() {
      _likedSongs = LikedSongsService.getLikedSongs();
    });

    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Removed from liked songs',
          style: const TextStyle(
            fontFamily: 'monospace',
          ),
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
