import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../models/music_model.dart';
import '../models/playlist_model.dart';
import '../services/youtube_search_service.dart';
import '../services/playlist_service.dart';
import '../services/playlist_songs_service.dart';
import '../services/cache_service.dart';
import '../controllers/music_player_controller.dart';
import '../services/liked_songs_service.dart';
import '../services/liked_playlists_service.dart';
import '../services/queue_playlist_service.dart';
import 'mini_music_player.dart';

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
  
  // Hover state management for Windows
  int? _hoveredPlaylistIndex;
  int? _hoveredMusicIndex;

  @override
  void initState() {
    super.initState();
    _fetchMusicData();
    _fetchTrendingPlaylists();
    _logCacheStatus();
    _initLikedPlaylistsService();
  }

  Future<void> _initLikedPlaylistsService() async {
    await LikedPlaylistsService.loadLikedPlaylists();
    await QueuePlaylistService.loadQueuePlaylists();
  }

  /// Log cache status for debugging
  Future<void> _logCacheStatus() async {
    final cacheStatus = await CacheService.getCacheStatus();
    final cacheSize = await CacheService.getCacheSize();
    print('📊 Cache Status: $cacheStatus');
    print('💾 Cache Size: ${cacheSize['totalSizeKB']} KB');
  }

  /// Show cache debug info (can be called from settings)
  static Future<String> getCacheDebugInfo() async {
    final cacheStatus = await CacheService.getCacheStatus();
    final cacheSize = await CacheService.getCacheSize();
    
    final musicStatus = cacheStatus['trendingMusic'] ?? {};
    final playlistsStatus = cacheStatus['trendingPlaylists'] ?? {};
    
    return '''
Cache Debug Info:
📱 Trending Music:
  • Cached: ${musicStatus['cached'] ?? false}
  • Valid: ${musicStatus['valid'] ?? false}
  • Age: ${musicStatus['age'] ?? 'N/A'}

📋 Trending Playlists:
  • Cached: ${playlistsStatus['cached'] ?? false}
  • Valid: ${playlistsStatus['valid'] ?? false}
  • Age: ${playlistsStatus['age'] ?? 'N/A'}

💾 Storage:
  • Total Size: ${cacheSize['totalSizeKB']} KB
  • Cache Duration: 2 hours
''';
  }

  Future<void> _fetchMusicData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First, try to get cached data
      final cachedTracks = await CacheService.getCachedTrendingMusic();
      
      if (cachedTracks != null && cachedTracks.isNotEmpty) {
        // Use cached data
        setState(() {
          _musicTracks = cachedTracks;
          _isLoading = false;
        });
        print('📱 Using cached trending music (${cachedTracks.length} tracks)');
        
        // Optionally fetch fresh data in background and update cache
        _refreshMusicDataInBackground();
        return;
      }
      
      // No valid cache, fetch fresh data
      print('🌐 Fetching fresh trending music from API');
      final response = await YoutubeSearchService.fetchTrendingMusic();
      
      setState(() {
        _musicTracks = response.trendingMusic;
        _isLoading = false;
      });
      
      // Cache the fresh data
      await CacheService.cacheTrendingMusic(response.trendingMusic);
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Refresh music data in background without showing loading state
  Future<void> _refreshMusicDataInBackground() async {
    try {
      print('🔄 Refreshing trending music in background');
      final response = await YoutubeSearchService.fetchTrendingMusic();
      
      // Update cache with fresh data
      await CacheService.cacheTrendingMusic(response.trendingMusic);
      
      // Silently update UI if data has changed
      if (mounted && response.trendingMusic.length != _musicTracks.length) {
        setState(() {
          _musicTracks = response.trendingMusic;
        });
        print('✅ Updated trending music with fresh data');
      }
    } catch (e) {
      print('❌ Background refresh failed: $e');
      // Silently fail - user still has cached data
    }
  }

  Future<void> _fetchTrendingPlaylists() async {
    setState(() {
      _isLoadingPlaylists = true;
      _playlistErrorMessage = null;
    });

    try {
      // First, try to get cached data
      final cachedPlaylists = await CacheService.getCachedTrendingPlaylists();
      
      if (cachedPlaylists != null && cachedPlaylists.isNotEmpty) {
        // Use cached data
        setState(() {
          _trendingPlaylists = cachedPlaylists;
          _isLoadingPlaylists = false;
        });
        print('📱 Using cached trending playlists (${cachedPlaylists.length} playlists)');
        
        // Optionally fetch fresh data in background and update cache
        _refreshPlaylistsDataInBackground();
        return;
      }
      
      // No valid cache, fetch fresh data
      print('🌐 Fetching fresh trending playlists from API');
      final playlists = await PlaylistService.getTrendingPlaylists();
      
      setState(() {
        _trendingPlaylists = playlists;
        _isLoadingPlaylists = false;
      });
      
      // Cache the fresh data
      await CacheService.cacheTrendingPlaylists(playlists);
      
    } catch (e) {
      setState(() {
        _playlistErrorMessage = e.toString();
        _isLoadingPlaylists = false;
      });
    }
  }

  /// Refresh playlists data in background without showing loading state
  Future<void> _refreshPlaylistsDataInBackground() async {
    try {
      print('🔄 Refreshing trending playlists in background');
      final playlists = await PlaylistService.getTrendingPlaylists();
      
      // Update cache with fresh data
      await CacheService.cacheTrendingPlaylists(playlists);
      
      // Silently update UI if data has changed
      if (mounted && playlists.length != _trendingPlaylists.length) {
        setState(() {
          _trendingPlaylists = playlists;
        });
        print('✅ Updated trending playlists with fresh data');
      }
    } catch (e) {
      print('❌ Background playlist refresh failed: $e');
      // Silently fail - user still has cached data
    }
  }

  /// Force fetch fresh music data (for manual refresh)
  Future<void> _fetchFreshMusicData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🌐 Force fetching fresh trending music from API');
      final response = await YoutubeSearchService.fetchTrendingMusic();
      
      setState(() {
        _musicTracks = response.trendingMusic;
        _isLoading = false;
      });
      
      // Update cache with fresh data
      await CacheService.cacheTrendingMusic(response.trendingMusic);
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Force fetch fresh playlists data (for manual refresh)
  Future<void> _fetchFreshPlaylistsData() async {
    setState(() {
      _isLoadingPlaylists = true;
      _playlistErrorMessage = null;
    });

    try {
      print('🌐 Force fetching fresh trending playlists from API');
      final playlists = await PlaylistService.getTrendingPlaylists();
      
      setState(() {
        _trendingPlaylists = playlists;
        _isLoadingPlaylists = false;
      });
      
      // Update cache with fresh data
      await CacheService.cacheTrendingPlaylists(playlists);
      
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
      backgroundColor: const Color(0xFF121212), // Black background
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFF1DB954), // Spotify green
              Color(0xFF1ED760), // Lighter green
            ],
          ).createShader(bounds),
          child: const Text(
            'ViBra',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'CascadiaCode',
              fontSize: 22,
              letterSpacing: 1.2,
            ),
          ),
        ),
        centerTitle: false,
        titleSpacing: 16.0,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Clear cache and fetch fresh data when manually refreshing
          print('🔄 Manual refresh - clearing cache and fetching fresh data');
          
          // Show a brief message about refreshing
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Refreshing with latest data...',
                  style: TextStyle(fontFamily: 'CascadiaCode'),
                ),
                backgroundColor: const Color(0xFF1C1C1E),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          
          await Future.wait([
            _fetchFreshMusicData(),
            _fetchFreshPlaylistsData(),
          ]);
        },
        backgroundColor: const Color(0xFF1E1E1E), // Dark background
        color: const Color(0xFF1DB954), // Spotify green
        strokeWidth: 3,
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
              color: const Color(0xFF1DB954), // Spotify green
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading content...',
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontFamily: 'CascadiaCode',
              ),
            ),
          ],
        ),
      );
    }

    // Use side-by-side layout for Windows desktop
    if (Platform.isWindows) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left half - Playlists
          Expanded(
            flex: 1,
            child: _buildPlaylistsSection(),
          ),
          // Divider
          Container(
            width: 1,
            color: const Color(0xFF2A2A2A), // Darker divider
            margin: const EdgeInsets.symmetric(vertical: 16),
          ),
          // Right half - Music with mini player
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Music section takes most of the space
                Expanded(
                  child: _buildMusicSection(),
                ),
                // Mini music player at the bottom
                const MiniMusicPlayer(),
              ],
            ),
          ),
        ],
      );
    }

    // Default vertical layout for mobile
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'CascadiaCode',
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (_isLoadingPlaylists)
          SizedBox(
            height: Platform.isWindows ? 300 : 170,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF1DB954), // Spotify green
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading playlists...',
                    style: const TextStyle(
                      color: Color(0xFFB3B3B3),
                      fontFamily: 'CascadiaCode',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_playlistErrorMessage != null)
          Container(
            height: Platform.isWindows ? 300 : 170,
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
                      fontFamily: 'CascadiaCode',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _fetchFreshPlaylistsData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954), // Spotify green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20), // Rounded pill shape
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(fontFamily: 'CascadiaCode', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_trendingPlaylists.isEmpty)
          Container(
            height: Platform.isWindows ? 300 : 170,
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
                      fontFamily: 'CascadiaCode',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Platform.isWindows 
            ? _buildWindowsPlaylistGrid()
            : _buildMobilePlaylistList(),
      ],
    );
  }

  Widget _buildWindowsPlaylistGrid() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _trendingPlaylists.length,
        itemBuilder: (context, index) {
          return _buildWindowsPlaylistListItem(_trendingPlaylists[index], index);
        },
      ),
    );
  }

  Widget _buildMobilePlaylistList() {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _trendingPlaylists.length,
        itemBuilder: (context, index) {
          return _buildPlaylistCard(_trendingPlaylists[index]);
        },
      ),
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
                    Color(0xFF6366F1), // Purple
                    Color(0xFFDC2626), // Red
                    Color(0xFFEF4444), // Lighter red
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF121212), // Match main background
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
                                color: Color(0xFF6366F1), // Purple
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
                fontFamily: 'CascadiaCode',
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

  Widget _buildWindowsPlaylistListItem(Playlist playlist, int index) {
    final isHovered = _hoveredPlaylistIndex == index;
    
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hoveredPlaylistIndex = index;
        });
      },
      onExit: (_) {
        setState(() {
          _hoveredPlaylistIndex = null;
        });
      },
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: GestureDetector(
          onTap: () => _onPlaylistTap(playlist),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isHovered ? const Color(0xFF2A2A2E).withOpacity(0.7) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovered ? const Color(0xFF6366F1).withOpacity(0.3) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Circular playlist image with gradient border
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isHovered ? 50 : 48,
                  height: isHovered ? 50 : 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isHovered ? [
                        const Color(0xFF6366F1),
                        const Color(0xFFDC2626),
                        const Color(0xFFEF4444),
                        const Color(0xFFF87171),
                      ] : [
                        const Color(0xFF6366F1),
                        const Color(0xFFDC2626),
                        const Color(0xFFEF4444),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(isHovered ? 0.4 : 0.3),
                        blurRadius: isHovered ? 12 : 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: Image.network(
                            playlist.thumbnail,
                            width: isHovered ? 42 : 40,
                            height: isHovered ? 42 : 40,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: isHovered ? 42 : 40,
                                height: isHovered ? 42 : 40,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1C1C1E),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: isHovered ? 42 : 40,
                                height: isHovered ? 42 : 40,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1C1C1E),
                                ),
                                child: const Icon(
                                  Icons.playlist_play,
                                  color: Color(0xFF666666),
                                  size: 20,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          color: isHovered ? Colors.white : Colors.white.withOpacity(0.9),
                          fontSize: isHovered ? 15 : 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'CascadiaCode',
                        ),
                        child: Text(
                          playlist.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          color: isHovered 
                              ? const Color(0xFF6366F1).withOpacity(0.8)
                              : Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontFamily: 'CascadiaCode',
                        ),
                        child: Text(
                          playlist.section,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: isHovered 
                        ? Colors.white.withOpacity(0.7) 
                        : Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'CascadiaCode',
                  ),
                  child: const Text('Playlist'),
                ),
                const SizedBox(width: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _showPlaylistOptions(playlist),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.more_vert,
                          color: isHovered 
                              ? Colors.white.withOpacity(0.8) 
                              : Colors.white.withOpacity(0.6),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onPlaylistTap(Playlist playlist) {
    _showPlaylistSongsDrawer(playlist);
  }

  void _showPlaylistOptions(Playlist playlist) {
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
                'View Playlist', 
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _onPlaylistTap(playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text(
                'Share', 
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'CascadiaCode',
              letterSpacing: 0.5,
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
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'CascadiaCode',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchFreshMusicData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954), // Spotify green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20), // Rounded pill shape
                      ),
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
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
          )
        else
          Platform.isWindows
              ? _buildWindowsMusicList()
              : _buildMobileMusicList(),
      ],
    );
  }

  Widget _buildWindowsMusicList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _musicTracks.length,
        itemBuilder: (context, index) {
          return _buildWindowsMusicTrackItem(_musicTracks[index], index);
        },
      ),
    );
  }

  Widget _buildMobileMusicList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _musicTracks.length,
      itemBuilder: (context, index) {
        return _buildMusicTrackItem(_musicTracks[index]);
      },
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
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
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
                      fontFamily: 'CascadiaCode',
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
                      fontFamily: 'CascadiaCode',
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
                fontFamily: 'CascadiaCode',
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

  Widget _buildWindowsMusicTrackItem(MusicTrack track, int index) {
    final isHovered = _hoveredMusicIndex == index;
    
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hoveredMusicIndex = index;
        });
      },
      onExit: (_) {
        setState(() {
          _hoveredMusicIndex = null;
        });
      },
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: GestureDetector(
          onTap: () => _playTrack(track),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isHovered ? const Color(0xFF2A2A2E).withOpacity(0.7) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovered ? const Color(0xFF6366F1).withOpacity(0.3) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: track.thumbnail.isNotEmpty
                      ? Image.network(
                          track.thumbnail,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 48,
                              height: 48,
                              color: const Color(0xFF1C1C1E),
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.music_note,
                                color: Color(0xFF666666),
                                size: 20,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Color(0xFF666666),
                            size: 20,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          color: isHovered ? Colors.white : Colors.white.withOpacity(0.9),
                          fontSize: isHovered ? 15 : 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'CascadiaCode',
                        ),
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          color: isHovered 
                              ? Colors.white.withOpacity(0.8) 
                              : Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontFamily: 'CascadiaCode',
                        ),
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: isHovered 
                        ? Colors.white.withOpacity(0.7) 
                        : Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'CascadiaCode',
                  ),
                  child: Text(track.durationString),
                ),
                const SizedBox(width: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _showTrackOptions(track),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.more_vert,
                          color: isHovered 
                              ? Colors.white.withOpacity(0.8) 
                              : Colors.white.withOpacity(0.6),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                  fontFamily: 'CascadiaCode',
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
                color: isLiked ? const Color(0xFF6366F1) : Colors.white
              ),
              title: Text(
                isLiked ? 'Unlike' : 'Like', 
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
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
                  fontFamily: 'CascadiaCode',
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
          style: const TextStyle(fontFamily: 'CascadiaCode'),
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _playTrack(MusicTrack track) {
    // Use recommendations instead of trending list for better discovery
    MusicPlayerController().playTrackWithRecommendations(track);
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

  Future<void> _togglePlaylistLike() async {
    try {
      final isNowLiked = await LikedPlaylistsService.togglePlaylistLike(
        playlistId: widget.playlist.playlistId,
        title: widget.playlist.title,
        channelName: widget.playlist.description.isNotEmpty 
            ? widget.playlist.description 
            : widget.playlist.section,
        playlistUrl: widget.playlist.url,
        thumbnailUrl: widget.playlist.thumbnail,
        source: 'trending',
      );
      
      if (mounted) {
        setState(() {
          // Trigger UI update
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNowLiked 
                  ? 'Added "${widget.playlist.title}" to liked playlists'
                  : 'Removed "${widget.playlist.title}" from liked playlists',
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: const Color(0xFF1C1C1E),
            duration: const Duration(seconds: 2),
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
              'Failed to update playlist: $e',
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
                          fontFamily: 'CascadiaCode',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.playlist.section,
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 14,
                          fontFamily: 'CascadiaCode',
                        ),
                      ),
                      if (_songs.isNotEmpty)
                        Text(
                          '${_songs.length} songs',
                          style: const TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 12,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                    ],
                  ),
                ),
                // Like button
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    onPressed: () => _togglePlaylistLike(),
                    icon: Icon(
                      LikedPlaylistsService.isPlaylistLiked(widget.playlist.playlistId)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: LikedPlaylistsService.isPlaylistLiked(widget.playlist.playlistId)
                          ? const Color(0xFF6366F1)
                          : Colors.white,
                      size: 28,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2E).withOpacity(0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
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
                  backgroundColor: const Color(0xFF6366F1),
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
                    fontFamily: 'CascadiaCode',
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
              color: Color(0xFF6366F1),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Loading songs...',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'CascadiaCode',
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
                fontFamily: 'CascadiaCode',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'CascadiaCode',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPlaylistSongs,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontFamily: 'CascadiaCode'),
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
                fontFamily: 'CascadiaCode',
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
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
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
                      fontFamily: 'CascadiaCode',
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
                      fontFamily: 'CascadiaCode',
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
                fontFamily: 'CascadiaCode',
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
                  fontFamily: 'CascadiaCode',
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
                color: isLiked ? const Color(0xFF6366F1) : Colors.white
              ),
              title: Text(
                isLiked ? 'Unlike' : 'Like', 
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
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
                  fontFamily: 'CascadiaCode',
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
