import 'package:flutter/material.dart';
import '../models/music_model.dart';
import '../models/playlist_model.dart';
import '../services/music_service.dart';
import '../services/playlist_service.dart';
import '../services/playlist_songs_service.dart';
import '../controllers/music_player_controller.dart';
import '../services/liked_songs_service.dart';

class MusicQueuePage extends StatefulWidget {
  const MusicQueuePage({super.key});

  @override
  State<MusicQueuePage> createState() => _MusicQueuePageState();
}

class _MusicQueuePageState extends State<MusicQueuePage> {
  List<MusicTrack> _musicTracks = [];
  List<Playlist> _trendingPlaylists = [];
  bool _isLoading = true;
  bool _isLoadingPlaylists = true;
  String? _errorMessage;
  String? _playlistErrorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMusicData();
    _fetchTrendingPlaylists();
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

  Future<void> _fetchTrendingPlaylists() async {
    setState(() {
      _isLoadingPlaylists = true;
      _playlistErrorMessage = null;
    });

    try {
      final playlists = await PlaylistService.getTrendingPlaylists();
      setState(() {
        _trendingPlaylists = playlists;
        _isLoadingPlaylists = false;
      });
    } catch (e) {
      setState(() {
        _playlistErrorMessage = e.toString();
        _isLoadingPlaylists = false;
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
        centerTitle: false,
        titleSpacing: 16.0,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _fetchMusicData(),
            _fetchTrendingPlaylists(),
          ]);
        },
        backgroundColor: const Color(0xFF1C1C1E),
        color: const Color(0xFFB91C1C),
        strokeWidth: 2.5,
        displacement: 40,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _isLoadingPlaylists) {
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
              'Loading content...',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildPlaylistsSection(),
        ),
        SliverToBoxAdapter(
          child: _buildMusicSection(),
        ),
      ],
    );
  }

  Widget _buildPlaylistsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Trending Playlists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (_isLoadingPlaylists)
          const SizedBox(
            height: 170,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFB91C1C),
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Loading playlists...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_playlistErrorMessage != null)
          Container(
            height: 170,
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Failed to load playlists',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _fetchTrendingPlaylists,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_trendingPlaylists.isEmpty)
          Container(
            height: 170,
            padding: const EdgeInsets.all(16.0),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_remove, color: Color(0xFF666666), size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No playlists available',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _trendingPlaylists.length,
              itemBuilder: (context, index) {
                return _buildPlaylistCard(_trendingPlaylists[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    return GestureDetector(
      onTap: () => _onPlaylistTap(playlist),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            // Circular playlist image with gradient border
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFB91C1C),
                    Color(0xFFDC2626),
                    Color(0xFFEF4444),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB91C1C).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: ClipOval(
                      child: Image.network(
                        playlist.thumbnail,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1C1C1E),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFB91C1C),
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1C1C1E),
                            ),
                            child: const Icon(
                              Icons.playlist_play,
                              color: Color(0xFF666666),
                              size: 28,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Playlist title
            Text(
              playlist.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onPlaylistTap(Playlist playlist) {
    _showPlaylistSongsDrawer(playlist);
  }

  void _showPlaylistSongsDrawer(Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PlaylistSongsDrawer(playlist: playlist),
    );
  }

  Widget _buildMusicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Trending Music',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (_errorMessage != null)
          Center(
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
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchMusicData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_musicTracks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No music available',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _musicTracks.length,
            itemBuilder: (context, index) {
              return _buildMusicTrackItem(_musicTracks[index]);
            },
          ),
      ],
    );
  }

  Widget _buildMusicTrackItem(MusicTrack track) {
    return GestureDetector(
      onTap: () => _playTrack(track),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: track.thumbnail.isNotEmpty
                  ? Image.network(
                      track.thumbnail,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
    final isLiked = LikedSongsService.isTrackLiked(track.webpageUrl);
    
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
              leading: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border, 
                color: isLiked ? const Color(0xFFB91C1C) : Colors.white
              ),
              title: Text(
                isLiked ? 'Unlike' : 'Like', 
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleLike(track);
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
          ],
        ),
      ),
    );
  }
  
  void _toggleLike(MusicTrack track) async {
    final isLiked = await LikedSongsService.toggleLikedSong(track);
    
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

  void _playTrack(MusicTrack track) {
    final trackIndex = _musicTracks.indexWhere((t) => t.webpageUrl == track.webpageUrl);
    if (trackIndex != -1) {
      MusicPlayerController().playTrackFromQueue(_musicTracks, trackIndex);
    } else {
      MusicPlayerController().playTrack(track);
    }
  }
}

class PlaylistSongsDrawer extends StatefulWidget {
  final Playlist playlist;

  const PlaylistSongsDrawer({super.key, required this.playlist});

  @override
  State<PlaylistSongsDrawer> createState() => _PlaylistSongsDrawerState();
}

class _PlaylistSongsDrawerState extends State<PlaylistSongsDrawer> {
  List<MusicTrack> _songs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPlaylistSongs();
  }

  Future<void> _fetchPlaylistSongs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final songs = await PlaylistSongsService.getPlaylistSongs(widget.playlist.playlistId);
      setState(() {
        _songs = songs;
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
    final screenHeight = MediaQuery.of(context).size.height;
    final drawerHeight = screenHeight * 0.7; // 70% of screen height

    return Container(
      height: drawerHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF666666),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Playlist header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.playlist.thumbnail,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.playlist_play,
                          color: Color(0xFF666666),
                          size: 32,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playlist.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.playlist.section,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (_songs.isNotEmpty)
                        Text(
                          '${_songs.length} songs',
                          style: const TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Play all button
          if (_songs.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _playAllSongs(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'Play All',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Songs list
          Expanded(
            child: _buildSongsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsList() {
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
              'Loading songs...',
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load songs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPlaylistSongs,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      );
    }

    if (_songs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, color: Color(0xFF666666), size: 48),
            SizedBox(height: 16),
            Text(
              'No songs in this playlist',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _songs.length,
      itemBuilder: (context, index) {
        return _buildSongItem(_songs[index], index);
      },
    );
  }

  Widget _buildSongItem(MusicTrack song, int index) {
    return GestureDetector(
      onTap: () => _playSong(song, index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Song thumbnail with high quality
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                song.posterImage.isNotEmpty ? song.posterImage : song.thumbnail,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 56,
                    height: 56,
                    color: const Color(0xFF2C2C2E),
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
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: Color(0xFF666666),
                      size: 24,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 13,
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
              song.durationString,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            
            // More options
            GestureDetector(
              onTap: () => _showSongOptions(song),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF666666),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playAllSongs() {
    if (_songs.isNotEmpty) {
      Navigator.pop(context);
      MusicPlayerController().playTrackFromQueue(_songs, 0);
    }
  }

  void _playSong(MusicTrack song, int index) {
    Navigator.pop(context);
    MusicPlayerController().playTrackFromQueue(_songs, index);
  }

  void _showSongOptions(MusicTrack song) {
    final isLiked = LikedSongsService.isTrackLiked(song.webpageUrl);
    
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
                final index = _songs.indexWhere((s) => s.webpageUrl == song.webpageUrl);
                _playSong(song, index);
              },
            ),
            ListTile(
              leading: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border, 
                color: isLiked ? const Color(0xFFB91C1C) : Colors.white
              ),
              title: Text(
                isLiked ? 'Unlike' : 'Like', 
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleLike(song);
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
          ],
        ),
      ),
    );
  }
  
  void _toggleLike(MusicTrack track) async {
    final isLiked = await LikedSongsService.toggleLikedSong(track);
    
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
