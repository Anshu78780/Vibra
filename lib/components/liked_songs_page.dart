import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';
import '../models/music_model.dart';
import '../controllers/music_player_controller.dart';
import '../services/liked_songs_service.dart';
import '../services/user_playlist_service.dart';
import '../services/download_service.dart';
import '../services/liked_playlists_service.dart';
import '../services/queue_playlist_service.dart';
import '../utils/app_colors.dart';
import 'mini_music_player.dart';

class LikedSongsPage extends StatefulWidget {
  const LikedSongsPage({super.key});

  @override
  State<LikedSongsPage> createState() => _LikedSongsPageState();
}

class _LikedSongsPageState extends State<LikedSongsPage>
    with SingleTickerProviderStateMixin {
  List<MusicTrack> _likedSongs = [];
  List<UserPlaylist> _userPlaylists = [];
  List<LikedPlaylist> _likedPlaylists = [];
  bool _isLoading = true;
  TabController? _tabController;
  bool _isDownloadingLikedSongs = false;
  
  // Download service and streams
  final DownloadService _downloadService = DownloadService();
  StreamSubscription? _bulkDownloadSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _setupBulkDownloadListener();
    _initLikedPlaylistsService();
  }

  Future<void> _initLikedPlaylistsService() async {
    await LikedPlaylistsService.loadLikedPlaylists();
    await QueuePlaylistService.loadQueuePlaylists();
    if (mounted) {
      setState(() {
        _likedPlaylists = LikedPlaylistsService.getLikedPlaylists();
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _bulkDownloadSubscription?.cancel();
    super.dispose();
  }

  void _setupBulkDownloadListener() {
    _bulkDownloadSubscription = _downloadService.bulkDownloadStream.listen((status) {
      if (mounted) {
        setState(() {
          _isDownloadingLikedSongs = status.isDownloading;
        });
        
        if (!status.isDownloading && status.totalTracks > 0) {
          // Show completion snackbar for liked songs
          _showLikedSongsDownloadCompletion(status);
        }
      }
    });
  }

  void _downloadAllLikedSongs() async {
    if (_likedSongs.isEmpty || _isDownloadingLikedSongs) return;
    
    // Show confirmation dialog
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Download All Liked Songs',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'CascadiaCode',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will download ${_likedSongs.length} liked songs. Downloads will happen in the background.\n\nNote: Downloads require mobile data or Wi-Fi.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'CascadiaCode',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryLinearGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text(
                'Download All',
                style: TextStyle(
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDownload == true) {
      setState(() {
        _isDownloadingLikedSongs = true;
      });

      try {
        await _downloadService.downloadAllTracks(_likedSongs, maxConcurrent: 2);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to start downloads: $e',
                style: const TextStyle(fontFamily: 'CascadiaCode'),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showLikedSongsDownloadCompletion(BulkDownloadStatus status) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎵 Liked Songs Download Complete!',
                style: const TextStyle(
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '✅ ${status.completedTracks} songs downloaded successfully',
                style: const TextStyle(fontFamily: 'CascadiaCode'),
              ),
              if (status.failedTracks > 0)
                Text(
                  '❌ ${status.failedTracks} songs failed',
                  style: const TextStyle(fontFamily: 'CascadiaCode'),
                ),
            ],
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _loadLikedPlaylists() async {
    try {
      await LikedPlaylistsService.loadLikedPlaylists();
      final likedPlaylists = LikedPlaylistsService.getLikedPlaylists();
      
      if (mounted) {
        setState(() {
          _likedPlaylists = likedPlaylists;
        });
      }
    } catch (e) {
      debugPrint('Error loading liked playlists: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Load both liked songs and user playlists
    await Future.wait([
      _loadLikedSongs(),
      _loadUserPlaylists(),
    ]);
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadLikedSongs() async {
    await LikedSongsService.loadCachedLikedSongs();
    _likedSongs = LikedSongsService.getLikedSongs();
  }

  Future<void> _loadUserPlaylists() async {
    await UserPlaylistService.loadCachedPlaylists();
    _userPlaylists = UserPlaylistService.getUserPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Your Music',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        titleSpacing: 16.0,
        elevation: 0,
        actions: [
          if (_tabController?.index == 0 && _likedSongs.isNotEmpty && !Platform.isWindows)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _isDownloadingLikedSongs
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _downloadAllLikedSongs,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryLinearGradient,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.download_for_offline_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      tooltip: 'Download All Liked Songs',
                    ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController!,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontFamily: 'CascadiaCode',
            fontWeight: FontWeight.w600,
          ),
          onTap: (index) {
            // Trigger rebuild to show/hide download button
            setState(() {});
          },
          tabs: const [
            Tab(text: 'Liked Songs'),
            Tab(text: 'My Playlists'),
            Tab(text: 'Liked Playlists'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController!,
        children: [
          RefreshIndicator(
            onRefresh: _loadLikedSongs,
            backgroundColor: AppColors.surface,
            color: AppColors.primary,
            strokeWidth: 2.5,
            displacement: 40,
            child: _buildLikedSongsTab(),
          ),
          RefreshIndicator(
            onRefresh: _loadUserPlaylists,
            backgroundColor: AppColors.surface,
            color: AppColors.primary,
            strokeWidth: 2.5,
            displacement: 40,
            child: _buildPlaylistsTab(),
          ),
          RefreshIndicator(
            onRefresh: _loadLikedPlaylists,
            backgroundColor: AppColors.surface,
            color: AppColors.primary,
            strokeWidth: 2.5,
            displacement: 40,
            child: _buildLikedPlaylistsTab(),
          ),
        ],
      ),
      floatingActionButton: (_tabController?.index == 1)
          ? FloatingActionButton(
              onPressed: _showAddPlaylistDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: AppColors.textPrimary),
            )
          : null,
    );
  }

  Widget _buildLikedSongsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
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
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No liked songs yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontFamily: 'CascadiaCode',
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your favorite songs will appear here',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontFamily: 'CascadiaCode',
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
                color: AppColors.cardBackground,
                height: 1,
                thickness: 0.5,
                indent: 88,
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      );
    }

    if (_userPlaylists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surface.withOpacity(0.8),
                    AppColors.cardBackground.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.cardBackground,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.playlist_add_rounded,
                size: 64,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No playlists yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'CascadiaCode',
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Import your favorite YouTube playlists\nto enjoy them anywhere',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontFamily: 'CascadiaCode',
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryLinearGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _showAddPlaylistDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(
                  Icons.add_rounded,
                  size: 24,
                ),
                label: const Text(
                  'Add Your First Playlist',
                  style: TextStyle(
                    fontFamily: 'CascadiaCode',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _userPlaylists.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final playlist = _userPlaylists[index];
        return _buildPlaylistTile(playlist);
      },
    );
  }

  Widget _buildPlaylistTile(UserPlaylist playlist) {
    return _InteractivePlaylistTile(
      playlist: playlist,
      onTap: () => _openPlaylist(playlist),
      onOptions: () => _showPlaylistOptions(playlist),
    );
  }

  Widget _buildLikedPlaylistsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      );
    }

    if (_likedPlaylists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 72,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No liked playlists yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'CascadiaCode',
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Like playlists from the home page to see them here',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontFamily: 'CascadiaCode',
                  height: 1.4,
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
      itemCount: _likedPlaylists.length,
      physics: const BouncingScrollPhysics(),
      cacheExtent: 1000,
      itemBuilder: (context, index) {
        final playlist = _likedPlaylists[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLikedPlaylistTile(playlist),
            if (index < _likedPlaylists.length - 1)
              const Divider(
                indent: 88,
                color: AppColors.cardBackground,
                height: 1,
              ),
          ],
        );
      },
    );
  }

  Widget _buildLikedPlaylistTile(LikedPlaylist playlist) {
    return _InteractiveLikedPlaylistTile(
      playlist: playlist,
      onTap: () => _openLikedPlaylist(playlist),
      onUnlike: () => _unlikePlaylist(playlist),
    );
  }

  Future<void> _unlikePlaylist(LikedPlaylist playlist) async {
    final success = await LikedPlaylistsService.unlikePlaylist(playlist.id);
    
    if (success && mounted) {
      await _loadLikedPlaylists();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Removed "${playlist.title}" from liked playlists',
            style: const TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: AppColors.surface,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openLikedPlaylist(LikedPlaylist playlist) {
    if (playlist.source == 'queue') {
      // Handle queue playlists - navigate to queue playlist details page
      final queueSongs = QueuePlaylistService.getQueuePlaylistSongs(playlist.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QueuePlaylistDetailsPage(
            playlist: playlist,
            songs: queueSongs,
          ),
        ),
      );
    } else {
      // Handle regular playlists (trending/user) - existing logic
      if (playlist.playlistUrl.isNotEmpty) {
        // For playlists with URLs, show playlist songs like before
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opening "${playlist.title}"...',
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: AppColors.surface,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // TODO: Implement playlist songs display for trending/user playlists
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot open playlist "${playlist.title}" - no URL available',
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  void _showAddPlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPlaylistDialog(
        onPlaylistAdded: () {
          _loadUserPlaylists().then((_) {
            setState(() {});
          });
        },
      ),
    );
  }

  void _showPlaylistOptions(UserPlaylist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: const Text(
                'Open Playlist',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _openPlaylist(playlist);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              title: const Text(
                'Delete Playlist',
                style: TextStyle(
                  color: AppColors.error,
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deletePlaylist(playlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deletePlaylist(UserPlaylist playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Playlist',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'CascadiaCode',
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'CascadiaCode',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await UserPlaylistService.removeUserPlaylist(playlist.id);
              await _loadUserPlaylists();
              setState(() {});
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Playlist "${playlist.name}" deleted',
                      style: const TextStyle(fontFamily: 'CascadiaCode'),
                    ),
                    backgroundColor: AppColors.surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPlaylist(UserPlaylist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserPlaylistDetailsPage(playlist: playlist),
      ),
    );
  }

  Widget _buildMusicTile(MusicTrack track) {
    return StreamBuilder<Map<String, double>>(
      stream: _downloadService.progressStream,
      builder: (context, progressSnapshot) {
        return FutureBuilder<bool>(
          future: _downloadService.isDownloaded(track),
          builder: (context, downloadSnapshot) {
            final isDownloaded = downloadSnapshot.data ?? false;
            final isDownloading = _downloadService.isDownloading(track);
            final progress = _downloadService.getDownloadProgress(track);
            
            return _InteractiveSongTile(
              track: track,
              isDownloaded: isDownloaded,
              isDownloading: isDownloading,
              progress: progress,
              onTap: () => _playTrack(track),
              onUnlike: () => _unlikeSong(track),
            );
          },
        );
      },
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
            fontFamily: 'CascadiaCode',
          ),
        ),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class AddPlaylistDialog extends StatefulWidget {
  final VoidCallback onPlaylistAdded;

  const AddPlaylistDialog({super.key, required this.onPlaylistAdded});

  @override
  State<AddPlaylistDialog> createState() => _AddPlaylistDialogState();
}

class _AddPlaylistDialogState extends State<AddPlaylistDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1C1C1E),
              Color(0xFF2C2C2E),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF3A3A3E),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon and title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF6366F1),
                          Color(0xFFDC2626),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.playlist_add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Playlist',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'CascadiaCode',
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Import your YouTube playlist',
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontFamily: 'CascadiaCode',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Playlist Name Field
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3A3A3E),
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'CascadiaCode',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Playlist Name',
                          labelStyle: const TextStyle(
                            color: Color(0xFF999999),
                            fontFamily: 'CascadiaCode',
                          ),
                          hintText: 'My Awesome Playlist',
                          hintStyle: const TextStyle(
                            color: Color(0xFF666666),
                            fontFamily: 'CascadiaCode',
                          ),
                          prefixIcon: const Icon(
                            Icons.music_note,
                            color: Color(0xFF6366F1),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // YouTube URL Field
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3A3A3E),
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _urlController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'CascadiaCode',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'YouTube Playlist URL',
                          labelStyle: const TextStyle(
                            color: Color(0xFF999999),
                            fontFamily: 'CascadiaCode',
                          ),
                          hintText: 'https://www.youtube.com/playlist?list=...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF666666),
                            fontFamily: 'CascadiaCode',
                            fontSize: 14,
                          ),
                          prefixIcon: Container(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/icons/youtube.png',
                              width: 20,
                              height: 20,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.link,
                                  color: Color(0xFF6366F1),
                                );
                              },
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a YouTube playlist URL';
                          }
                          if (!value.contains('youtube.com') && !value.contains('youtu.be')) {
                            return 'Please enter a valid YouTube URL';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'CascadiaCode',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4A4A4E),
                          width: 1,
                        ),
                      ),
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'CascadiaCode',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: _isLoading
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF6366F1),
                                  Color(0xFFDC2626),
                                ],
                              ),
                        color: _isLoading ? const Color(0xFF4A4A4E) : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isLoading
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: TextButton(
                        onPressed: _isLoading ? null : _addPlaylist,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                ),
                              )
                            : const Text(
                                'Add Playlist',
                                style: TextStyle(
                                  fontFamily: 'CascadiaCode',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addPlaylist() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await UserPlaylistService.addUserPlaylist(
      _nameController.text.trim(),
      _urlController.text.trim(),
    );

    setState(() {
      _isLoading = false;
    });

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    } else {
      Navigator.pop(context);
      widget.onPlaylistAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playlist "${_nameController.text.trim()}" added successfully!',
            style: const TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class UserPlaylistDetailsPage extends StatefulWidget {
  final UserPlaylist playlist;

  const UserPlaylistDetailsPage({super.key, required this.playlist});

  @override
  State<UserPlaylistDetailsPage> createState() => _UserPlaylistDetailsPageState();
}

class _UserPlaylistDetailsPageState extends State<UserPlaylistDetailsPage> {
  List<MusicTrack> _songs = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDownloadingAll = false;
  
  // Download service and streams
  final DownloadService _downloadService = DownloadService();
  StreamSubscription? _bulkDownloadSubscription;
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _loadPlaylistSongs();
    _setupBulkDownloadListener();
    _setupProgressListener();
  }

  @override
  void dispose() {
    _bulkDownloadSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _setupBulkDownloadListener() {
    _bulkDownloadSubscription = _downloadService.bulkDownloadStream.listen((status) {
      if (mounted) {
        setState(() {
          _isDownloadingAll = status.isDownloading;
        });
        
        if (!status.isDownloading && status.totalTracks > 0) {
          // Show completion dialog
          _showDownloadCompletionDialog(status);
        }
      }
    });
  }

  void _setupProgressListener() {
    _progressSubscription = _downloadService.progressStream.listen((progress) {
      if (mounted) {
        // Trigger rebuild to show/hide stop button based on active downloads
        setState(() {});
      }
    });
  }

  Future<void> _loadPlaylistSongs({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final songs = await UserPlaylistService.getPlaylistSongs(
        widget.playlist.playlistId, 
        forceRefresh: forceRefresh
      );
      
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
      
      // Show cache info in debug mode
      final cacheInfo = UserPlaylistService.getPlaylistCacheInfo(widget.playlist.playlistId);
      if (cacheInfo != null) {
        debugPrint('📊 Cache info for ${widget.playlist.name}: '
            '${cacheInfo['songsCount']} songs, '
            '${cacheInfo['ageHours']}h old, '
            'expired: ${cacheInfo['isExpired']}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.playlist.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          // Refresh cache button
          IconButton(
            onPressed: () async {
              debugPrint('🔄 Manual refresh requested for ${widget.playlist.name}');
              await _loadPlaylistSongs(forceRefresh: true);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Refreshed ${widget.playlist.name}',
                      style: const TextStyle(fontFamily: 'CascadiaCode'),
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
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white70,
              size: 24,
            ),
            tooltip: 'Refresh Playlist',
          ),
          if (_songs.isNotEmpty && !Platform.isWindows)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _isDownloadingAll
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _downloadAllSongs,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFDC2626)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.download_for_offline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      tooltip: 'Download All Songs',
                    ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadPlaylistSongs(forceRefresh: true),
        backgroundColor: const Color(0xFF1C1C1E),
        color: const Color(0xFF6366F1),
        strokeWidth: 2.5,
        displacement: 40,
        child: _buildBody(),
      ),
      bottomNavigationBar: const MiniMusicPlayer(),
    );
  }

  Widget _buildBody() {
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
              'Loading playlist...',
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
              'Failed to load playlist',
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
              onPressed: _loadPlaylistSongs,
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
              'No songs found',
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _songs.length,
      itemBuilder: (context, index) {
        return _buildSongItem(_songs[index], index);
      },
    );
  }

  Widget _buildSongItem(MusicTrack song, int index) {
    return StreamBuilder<Map<String, double>>(
      stream: _downloadService.progressStream,
      builder: (context, progressSnapshot) {
        return FutureBuilder<bool>(
          future: _downloadService.isDownloaded(song),
          builder: (context, downloadSnapshot) {
            final isDownloaded = downloadSnapshot.data ?? false;
            final isDownloading = _downloadService.isDownloading(song);
            final progress = _downloadService.getDownloadProgress(song);
            
            return GestureDetector(
              onTap: () => _playSong(song, index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Album artwork with download indicator overlay
                    Stack(
                      children: [
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
                        // Download status indicator
                        if (isDownloaded)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: const Color(0xFF1C1C1E), width: 1),
                              ),
                              child: const Icon(
                                Icons.download_done,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          )
                        else if (isDownloading)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: const Color(0xFF1C1C1E), width: 1),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    value: progress > 0 ? progress : null,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
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
                    Text(
                      song.durationString,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 12,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                    const SizedBox(width: 8),
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
        );
      }
    );
  }

  void _playSong(MusicTrack song, int index) {
    MusicPlayerController().playTrackFromQueue(_songs, index);
  }

  void _downloadAllSongs() async {
    if (_songs.isEmpty || _isDownloadingAll) return;
    
    // Show confirmation dialog
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Download All Songs',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'CascadiaCode',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will download ${_songs.length} songs from "${widget.playlist.name}". Downloads will happen in the background.\n\nNote: Downloads require mobile data or Wi-Fi.',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'CascadiaCode',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Download All',
                style: TextStyle(
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDownload == true) {
      setState(() {
        _isDownloadingAll = true;
      });

      try {
        await _downloadService.downloadAllTracks(_songs, maxConcurrent: 2);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to start downloads: $e',
                style: const TextStyle(fontFamily: 'CascadiaCode'),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showDownloadCompletionDialog(BulkDownloadStatus status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.download_done_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Downloads Complete',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✅ ${status.completedTracks} songs downloaded successfully',
              style: const TextStyle(
                color: Colors.green,
                fontFamily: 'CascadiaCode',
              ),
            ),
            if (status.failedTracks > 0) ...[
              const SizedBox(height: 8),
              Text(
                '❌ ${status.failedTracks} songs failed to download',
                style: const TextStyle(
                  color: Colors.red,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              if (status.failedTrackTitles.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Failed songs:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'CascadiaCode',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...status.failedTrackTitles.take(3).map(
                  (title) => Text(
                    '• $title',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'CascadiaCode',
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (status.failedTrackTitles.length > 3)
                  Text(
                    '• ... and ${status.failedTrackTitles.length - 3} more',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'CascadiaCode',
                      fontSize: 12,
                    ),
                  ),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontFamily: 'CascadiaCode',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
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
          ],
        ),
      ),
    );
  }
  
  void _toggleLike(MusicTrack track) async {
    final isLiked = await LikedSongsService.toggleLikedSong(track);
    
    if (mounted) {
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
}

// Playlist thumbnail widget that fetches and displays the playlist thumbnail
class _PlaylistThumbnail extends StatefulWidget {
  final UserPlaylist playlist;

  const _PlaylistThumbnail({required this.playlist});

  @override
  State<_PlaylistThumbnail> createState() => _PlaylistThumbnailState();
}

class _PlaylistThumbnailState extends State<_PlaylistThumbnail> {
  String? _thumbnailUrl;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Try to get the first song's thumbnail from the playlist (using cache when available)
      final songs = await UserPlaylistService.getPlaylistSongs(widget.playlist.playlistId);
      if (mounted && songs.isNotEmpty && songs.first.thumbnail.isNotEmpty) {
        setState(() {
          _thumbnailUrl = songs.first.thumbnail;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildThumbnailContent(),
      ),
    );
  }

  Widget _buildThumbnailContent() {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryLinearGradient,
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
            ),
          ),
        ),
      );
    }

    if (_hasError || _thumbnailUrl == null || _thumbnailUrl!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryLinearGradient,
        ),
        child: const Icon(
          Icons.playlist_play_rounded,
          color: AppColors.textPrimary,
          size: 32,
        ),
      );
    }

    return Image.network(
      _thumbnailUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryLinearGradient,
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryLinearGradient,
          ),
          child: const Icon(
            Icons.playlist_play_rounded,
            color: AppColors.textPrimary,
            size: 32,
          ),
        );
      },
    );
  }
}

// Hoverable icon button for desktop interactions
class _HoverableIconButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const _HoverableIconButton({
    required this.onPressed,
    required this.icon,
  });

  @override
  State<_HoverableIconButton> createState() => _HoverableIconButtonState();
}

class _HoverableIconButtonState extends State<_HoverableIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          setState(() {
            _isHovered = true;
          });
        }
      },
      onExit: (_) {
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          setState(() {
            _isHovered = false;
          });
        }
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered 
                ? AppColors.cardBackground.withOpacity(0.8)
                : AppColors.cardBackground.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            color: AppColors.textMuted,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// Queue Playlist Details Page for displaying saved queue playlists
class QueuePlaylistDetailsPage extends StatefulWidget {
  final LikedPlaylist playlist;
  final List<MusicTrack> songs;

  const QueuePlaylistDetailsPage({
    super.key,
    required this.playlist,
    required this.songs,
  });

  @override
  State<QueuePlaylistDetailsPage> createState() => _QueuePlaylistDetailsPageState();
}

class _QueuePlaylistDetailsPageState extends State<QueuePlaylistDetailsPage> {
  late List<MusicTrack> _songs;
  final DownloadService _downloadService = DownloadService();
  StreamSubscription? _bulkDownloadSubscription;
  StreamSubscription? _progressSubscription;
  bool _isDownloadingAll = false;

  @override
  void initState() {
    super.initState();
    _songs = widget.songs;
    _setupBulkDownloadListener();
    _setupProgressListener();
  }

  @override
  void dispose() {
    _bulkDownloadSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _setupBulkDownloadListener() {
    _bulkDownloadSubscription = _downloadService.bulkDownloadStream.listen((status) {
      if (mounted) {
        setState(() {
          _isDownloadingAll = status.isDownloading;
        });
        
        if (!status.isDownloading && status.totalTracks > 0) {
          _showDownloadCompletionDialog(status);
        }
      }
    });
  }

  void _setupProgressListener() {
    _progressSubscription = _downloadService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.playlist.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'CascadiaCode',
              ),
            ),
            Text(
              'Queue Playlist • ${_songs.length} songs',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'CascadiaCode',
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          if (_songs.isNotEmpty && !Platform.isWindows)
            IconButton(
              onPressed: _isDownloadingAll ? null : _downloadAllSongs,
              icon: _isDownloadingAll
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      color: Color(0xFF6366F1),
                    ),
              tooltip: _isDownloadingAll ? 'Downloading...' : 'Download All',
            ),
          IconButton(
            onPressed: () => _showQueuePlaylistOptions(),
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const MiniMusicPlayer(),
    );
  }

  Widget _buildBody() {
    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Queue playlist is empty',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
                fontFamily: 'CascadiaCode',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This saved queue no longer contains any songs',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontFamily: 'CascadiaCode',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Playlist info header
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Playlist thumbnail
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.purple, Color(0xFF6366F1)],
                  ),
                ),
                child: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(width: 16),
              // Playlist details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.channelName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved ${_formatDate(widget.playlist.likedAt)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                  ],
                ),
              ),
              // Play all button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Colors.purple],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: IconButton(
                  onPressed: () => _playAllSongs(),
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Songs list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              return _buildSongItem(_songs[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongItem(MusicTrack song, int index) {
    return StreamBuilder<Map<String, double>>(
      stream: _downloadService.progressStream,
      builder: (context, progressSnapshot) {
        return FutureBuilder<bool>(
          future: _downloadService.isDownloaded(song),
          builder: (context, downloadSnapshot) {
            final isDownloaded = downloadSnapshot.data ?? false;
            final progress = progressSnapshot.data?[song.webpageUrl];
            final isDownloading = progress != null && progress < 1.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF333333),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.thumbnail.isNotEmpty
                        ? Image.network(
                            song.thumbnail,
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
                title: Text(
                  song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'CascadiaCode',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontFamily: 'CascadiaCode',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFF333333),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDownloaded)
                      const Icon(
                        Icons.download_done_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                    IconButton(
                      onPressed: () => _showSongOptions(song),
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                onTap: () => _playSong(song, index),
              ),
            );
          },
        );
      },
    );
  }

  void _playSong(MusicTrack song, int index) {
    MusicPlayerController().playTrackFromQueue(_songs, index);
  }

  void _playAllSongs() {
    if (_songs.isNotEmpty) {
      MusicPlayerController().playTrackFromQueue(_songs, 0);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playing "${widget.playlist.title}" (${_songs.length} songs)',
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

  void _downloadAllSongs() async {
    if (_songs.isEmpty || _isDownloadingAll) return;
    
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Download All Songs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
          ),
        ),
        content: Text(
          'This will download ${_songs.length} songs from "${widget.playlist.title}". Downloads will happen in the background.\n\nNote: Downloads require mobile data or Wi-Fi.',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'CascadiaCode',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Colors.purple],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Download',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDownload == true) {
      setState(() {
        _isDownloadingAll = true;
      });

      try {
        await _downloadService.downloadAllTracks(_songs, maxConcurrent: 2);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Download failed: $e',
                style: const TextStyle(fontFamily: 'CascadiaCode'),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showDownloadCompletionDialog(BulkDownloadStatus status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Row(
          children: [
            Icon(Icons.download_done_rounded, color: Colors.green),
            SizedBox(width: 12),
            Text(
              'Download Complete',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully downloaded ${status.completedTracks} of ${status.totalTracks} songs from "${widget.playlist.title}".',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'CascadiaCode',
              ),
            ),
            if (status.failedTracks > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${status.failedTracks} songs failed to download.',
                style: const TextStyle(
                  color: Colors.orange,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQueuePlaylistOptions() {
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
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text(
                'Remove from Liked Playlists',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeFromLikedPlaylists();
              },
            ),
          ],
        ),
      ),
    );
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
              leading: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? const Color(0xFF6366F1) : Colors.white,
              ),
              title: Text(
                isLiked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
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
            if (!Platform.isWindows)
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.white),
                title: const Text(
                  'Download',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _downloadService.downloadTrack(song);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _toggleLike(MusicTrack track) async {
    final isLiked = await LikedSongsService.toggleLikedSong(track);
    
    if (mounted) {
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

  void _removeFromLikedPlaylists() async {
    final success = await LikedPlaylistsService.unlikePlaylist(widget.playlist.id);
    
    if (success && mounted) {
      Navigator.pop(context); // Go back to liked playlists page
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Removed "${widget.playlist.title}" from liked playlists',
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

// Interactive Song Tile widget with Windows hover effects
class _InteractiveSongTile extends StatefulWidget {
  final MusicTrack track;
  final bool isDownloaded;
  final bool isDownloading;
  final double? progress;
  final VoidCallback onTap;
  final VoidCallback onUnlike;

  const _InteractiveSongTile({
    required this.track,
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
    required this.onTap,
    required this.onUnlike,
  });

  @override
  State<_InteractiveSongTile> createState() => _InteractiveSongTileState();
}

class _InteractiveSongTileState extends State<_InteractiveSongTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isHeartHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: AppColors.surface.withOpacity(0.6),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      setState(() {
        _isHovered = isHovered;
      });
      
      if (isHovered) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _onHeartHoverChanged(bool isHovered) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      setState(() {
        _isHeartHovered = isHovered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return MouseRegion(
          cursor: Platform.isWindows || Platform.isMacOS || Platform.isLinux
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          onEnter: (_) => _onHoverChanged(true),
          onExit: (_) => _onHoverChanged(false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                height: 68,
                margin: _isHovered 
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                    : const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _colorAnimation.value,
                  borderRadius: _isHovered 
                      ? BorderRadius.circular(12)
                      : BorderRadius.circular(0),
                  border: _isHovered
                      ? Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        )
                      : null,
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    // Album artwork with download indicator overlay
                    _buildAlbumArtwork(),
                    const SizedBox(width: 16),
                    // Song info
                    Expanded(
                      child: _buildSongInfo(),
                    ),
                    // Duration
                    _buildDuration(),
                    const SizedBox(width: 16),
                    // Unlike option with hover effect
                    _buildUnlikeButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumArtwork() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_isHovered ? 12 : 8),
            child: widget.track.thumbnail.isNotEmpty
                ? Image.network(
                    widget.track.thumbnail,
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
                        color: AppColors.surface,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAlbumArt();
                    },
                  )
                : _buildDefaultAlbumArt(),
          ),
          // Download status indicator
          if (widget.isDownloaded)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.background, width: 1),
                ),
                child: const Icon(
                  Icons.download_done,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            )
          else if (widget.isDownloading)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.background, width: 1),
                ),
                child: Center(
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      value: widget.progress != null && widget.progress! > 0 ? widget.progress : null,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          // Play overlay on hover
          if (_isHovered && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAlbumArt() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_isHovered ? 12 : 8),
      ),
      child: const Icon(
        Icons.music_note,
        color: AppColors.textMuted,
        size: 24,
      ),
    );
  }

  Widget _buildSongInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: _isHovered ? AppColors.primary : AppColors.textPrimary,
            fontSize: 16,
            fontWeight: _isHovered ? FontWeight.w500 : FontWeight.w400,
            fontFamily: 'CascadiaCode',
          ),
          child: Text(
            widget.track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: 'CascadiaCode',
          ),
          child: Text(
            widget.track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDuration() {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        color: _isHovered ? AppColors.textPrimary : AppColors.textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'CascadiaCode',
      ),
      child: Text(widget.track.durationString),
    );
  }

  Widget _buildUnlikeButton() {
    return MouseRegion(
      cursor: Platform.isWindows || Platform.isMacOS || Platform.isLinux
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => _onHeartHoverChanged(true),
      onExit: (_) => _onHeartHoverChanged(false),
      child: GestureDetector(
        onTap: widget.onUnlike,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHeartHovered
                ? AppColors.primary.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: _isHeartHovered ? 1.2 : 1.0,
            child: Icon(
              Icons.favorite,
              color: _isHeartHovered ? AppColors.error : AppColors.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// Interactive Playlist Tile widget with Windows hover effects
class _InteractivePlaylistTile extends StatefulWidget {
  final UserPlaylist playlist;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  const _InteractivePlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onOptions,
  });

  @override
  State<_InteractivePlaylistTile> createState() => _InteractivePlaylistTileState();
}

class _InteractivePlaylistTileState extends State<_InteractivePlaylistTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _elevationAnimation = Tween<double>(
      begin: 8.0,
      end: 16.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      setState(() {
        _isHovered = isHovered;
      });
      
      if (isHovered) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return MouseRegion(
          cursor: Platform.isWindows || Platform.isMacOS || Platform.isLinux
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          onEnter: (_) => _onHoverChanged(true),
          onExit: (_) => _onHoverChanged(false),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHovered 
                      ? AppColors.primary.withOpacity(0.5)
                      : AppColors.cardBackground,
                  width: _isHovered ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered 
                        ? AppColors.primary.withOpacity(0.3)
                        : Colors.black.withOpacity(0.2),
                    blurRadius: _elevationAnimation.value,
                    offset: Offset(0, _elevationAnimation.value / 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Playlist thumbnail with enhanced hover effect
                        _buildPlaylistThumbnail(),
                        const SizedBox(width: 16),
                        
                        // Playlist info
                        Expanded(
                          child: _buildPlaylistInfo(),
                        ),
                        
                        // More options button with hover effect
                        _HoverableIconButton(
                          onPressed: widget.onOptions,
                          icon: Icons.more_vert_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistThumbnail() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: _isHovered 
          ? (Matrix4.identity()..rotateY(0.1))
          : Matrix4.identity(),
      child: Stack(
        children: [
          _PlaylistThumbnail(playlist: widget.playlist),
          // Play overlay on hover
          if (_isHovered && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: _isHovered ? AppColors.primary : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: _isHovered ? FontWeight.w700 : FontWeight.bold,
            fontFamily: 'CascadiaCode',
          ),
          child: Text(
            widget.playlist.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.access_time_rounded,
                color: _isHovered ? AppColors.primary : AppColors.textMuted,
                size: 14,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: _isHovered ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 13,
                fontFamily: 'CascadiaCode',
              ),
              child: Text('Added ${_formatDate(widget.playlist.createdAt)}'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                gradient: _isHovered 
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF8B5CF6), 
                          Color(0xFFEC4899),
                        ],
                      )
                    : AppColors.primaryLinearGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (_isHovered ? const Color(0xFF8B5CF6) : AppColors.primary)
                        .withOpacity(0.4),
                    blurRadius: _isHovered ? 8 : 4,
                    offset: Offset(0, _isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_filled,
                    color: AppColors.textPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'YouTube',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Interactive Liked Playlist Tile widget with Windows hover effects  
class _InteractiveLikedPlaylistTile extends StatefulWidget {
  final LikedPlaylist playlist;
  final VoidCallback onTap;
  final VoidCallback onUnlike;

  const _InteractiveLikedPlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onUnlike,
  });

  @override
  State<_InteractiveLikedPlaylistTile> createState() => _InteractiveLikedPlaylistTileState();
}

class _InteractiveLikedPlaylistTileState extends State<_InteractiveLikedPlaylistTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isHeartHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: AppColors.surface.withOpacity(0.6),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      setState(() {
        _isHovered = isHovered;
      });
      
      if (isHovered) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _onHeartHoverChanged(bool isHovered) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      setState(() {
        _isHeartHovered = isHovered;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return MouseRegion(
          cursor: Platform.isWindows || Platform.isMacOS || Platform.isLinux
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          onEnter: (_) => _onHoverChanged(true),
          onExit: (_) => _onHoverChanged(false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                height: 72,
                margin: _isHovered 
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                    : const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _colorAnimation.value,
                  borderRadius: _isHovered 
                      ? BorderRadius.circular(12)
                      : BorderRadius.circular(0),
                  border: _isHovered
                      ? Border.all(
                          color: widget.playlist.source == 'queue'
                              ? Colors.purple.withOpacity(0.3)
                              : AppColors.primary.withOpacity(0.3),
                          width: 1,
                        )
                      : null,
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: (widget.playlist.source == 'queue' 
                                ? Colors.purple 
                                : AppColors.primary).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    // Playlist thumbnail
                    _buildPlaylistThumbnail(),
                    const SizedBox(width: 16),
                    // Playlist info
                    Expanded(
                      child: _buildPlaylistInfo(),
                    ),
                    // Unlike option with hover effect
                    _buildUnlikeButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistThumbnail() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_isHovered ? 12 : 8),
            child: widget.playlist.thumbnailUrl.isNotEmpty
                ? Image.network(
                    widget.playlist.thumbnailUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 60,
                        height: 60,
                        color: AppColors.surface,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultPlaylistArt();
                    },
                  )
                : _buildDefaultPlaylistArt(),
          ),
          // Play overlay on hover
          if (_isHovered && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultPlaylistArt() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: widget.playlist.source == 'queue'
            ? const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              )
            : AppColors.primaryLinearGradient,
        borderRadius: BorderRadius.circular(_isHovered ? 12 : 8),
      ),
      child: Icon(
        widget.playlist.source == 'queue'
            ? Icons.queue_music_rounded
            : Icons.playlist_play_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  Widget _buildPlaylistInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: _isHovered 
                ? (widget.playlist.source == 'queue' ? Colors.purple : AppColors.primary)
                : AppColors.textPrimary,
            fontSize: 16,
            fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
            fontFamily: 'CascadiaCode',
          ),
          child: Text(
            widget.playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        // Channel name
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: 'CascadiaCode',
          ),
          child: Text(
            widget.playlist.channelName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        // Source badge and date info
        Row(
          children: [
            // Source badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.playlist.source == 'queue' 
                    ? (_isHovered ? Colors.purple.withOpacity(0.3) : Colors.purple.withOpacity(0.2))
                    : (_isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.primary.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.playlist.source == 'queue')
                    Icon(
                      Icons.queue_music_rounded,
                      color: _isHovered ? Colors.purple.withOpacity(0.9) : Colors.purple,
                      size: 12,
                    ),
                  if (widget.playlist.source == 'queue') const SizedBox(width: 4),
                  Text(
                    widget.playlist.source == 'trending' 
                        ? 'Trending' 
                        : widget.playlist.source == 'queue'
                            ? 'Queue'
                            : 'Custom',
                    style: TextStyle(
                      color: widget.playlist.source == 'queue' 
                          ? (_isHovered ? Colors.purple.withOpacity(0.9) : Colors.purple)
                          : (_isHovered ? AppColors.primary.withOpacity(0.9) : AppColors.primary),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Date
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: _isHovered ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize: 11,
                  fontFamily: 'CascadiaCode',
                ),
                child: Text(
                  _formatDate(widget.playlist.likedAt),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Queue song count
            if (widget.playlist.source == 'queue') ...[
              const SizedBox(width: 8),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: _isHovered ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'CascadiaCode',
                  ),
                  child: Text(
                    '${QueuePlaylistService.getQueuePlaylistSongs(widget.playlist.id).length} songs',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildUnlikeButton() {
    return MouseRegion(
      cursor: Platform.isWindows || Platform.isMacOS || Platform.isLinux
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => _onHeartHoverChanged(true),
      onExit: (_) => _onHeartHoverChanged(false),
      child: GestureDetector(
        onTap: widget.onUnlike,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHeartHovered
                ? AppColors.error.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: _isHeartHovered ? 1.2 : 1.0,
            child: Icon(
              Icons.favorite,
              color: _isHeartHovered 
                  ? AppColors.error 
                  : (widget.playlist.source == 'queue' ? Colors.purple : AppColors.primary),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
