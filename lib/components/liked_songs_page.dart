import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../models/music_model.dart';
import '../controllers/music_player_controller.dart';
import '../services/liked_songs_service.dart';
import '../services/user_playlist_service.dart';
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
  bool _isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tabController!,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontFamily: 'CascadiaCode',
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Liked Songs'),
            Tab(text: 'My Playlists'),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBackground,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPlaylist(playlist),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Playlist thumbnail with hover effect
                _PlaylistThumbnail(playlist: playlist),
                const SizedBox(width: 16),
                
                // Playlist info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'CascadiaCode',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: AppColors.textMuted,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Added ${_formatDate(playlist.createdAt)}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontFamily: 'CascadiaCode',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryLinearGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
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
                  ),
                ),
                
                // More options button with hover effect
                _HoverableIconButton(
                  onPressed: () => _showPlaylistOptions(playlist),
                  icon: Icons.more_vert_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                        return Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: AppColors.textMuted,
                            size: 24,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: AppColors.textMuted,
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
                      color: AppColors.textPrimary,
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
                      color: AppColors.textSecondary,
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
            // Duration
            Text(
              track.durationString,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'CascadiaCode',
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
                  color: AppColors.primary,
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

  @override
  void initState() {
    super.initState();
    _loadPlaylistSongs();
  }

  Future<void> _loadPlaylistSongs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final songs = await UserPlaylistService.getPlaylistSongs(widget.playlist.playlistId);
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
      ),
      body: RefreshIndicator(
        onRefresh: _loadPlaylistSongs,
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
    return GestureDetector(
      onTap: () => _playSong(song, index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
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

  void _playSong(MusicTrack song, int index) {
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
      // Try to get the first song's thumbnail from the playlist
      final songs = await UserPlaylistService.getPlaylistSongs(widget.playlist.playlistId);
      if (songs.isNotEmpty && songs.first.thumbnail.isNotEmpty) {
        setState(() {
          _thumbnailUrl = songs.first.thumbnail;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
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
