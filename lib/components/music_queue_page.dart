import 'package:flutter/material.dart';
import '../models/music_model.dart';
import '../services/music_service.dart';

class MusicQueuePage extends StatefulWidget {
  const MusicQueuePage({super.key});

  @override
  State<MusicQueuePage> createState() => _MusicQueuePageState();
}

class _MusicQueuePageState extends State<MusicQueuePage> {
  List<MusicTrack> _musicTracks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMusicData();
  }

  Future<void> _fetchMusicData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await MusicService.fetchTrendingMusic();
      setState(() {
        _musicTracks = response.trendingMusic;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'vibra',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontSize: 20,
          ),
        ),
        centerTitle: false, // This aligns the title to the left
        titleSpacing: 16.0, // Add some spacing from the left edge
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMusicData,
        backgroundColor: const Color(0xFF1C1C1E),
        color: const Color(0xFFB91C1C), // Darker red like Apple Music
        strokeWidth: 2.5,
        displacement: 40,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFB91C1C),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Loading trending music...',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load music',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchMusicData,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: _buildMusicQueue()),
      ],
    );
  }

  Widget _buildMusicQueue() {
    if (_musicTracks.isEmpty) {
      return const Center(
        child: Text(
          'No music tracks found',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _musicTracks.length,
      physics: const BouncingScrollPhysics(), // iOS-like smooth scrolling
      cacheExtent: 1000, // Pre-render items for smoother scrolling
      itemExtent: 80, // Fixed height for better performance
      itemBuilder: (context, index) {
        final track = _musicTracks[index];
        return Column(
          mainAxisSize: MainAxisSize.min, // Better performance
          children: [
            _buildMusicTile(track),
            if (index < _musicTracks.length - 1)
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
      behavior: HitTestBehavior.opaque, // Better tap detection
      child: Container(
        height: 68, // Fixed height for consistent performance
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // Album artwork with optimized loading
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: track.thumbnail.isNotEmpty
                  ? Image.network(
                      track.thumbnail,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      cacheWidth: 112, // Cache at 2x resolution for retina displays
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
            // More options button
            GestureDetector(
              onTap: () => _showTrackOptions(track),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF666666),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(MusicTrack track) {
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
              leading: const Icon(Icons.play_arrow, color: Colors.white),
              title: const Text(
                'Play', 
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _playTrack(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border, color: Colors.white),
              title: const Text(
                'Like', 
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () => Navigator.pop(context),
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
          ],
        ),
      ),
    );
  }

  void _playTrack(MusicTrack track) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Playing: ${track.title} by ${track.artist}',
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        backgroundColor: const Color(0xFFB91C1C),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
