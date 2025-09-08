import 'package:flutter/material.dart';
import '../services/user_playlist_service.dart';
import '../utils/app_colors.dart';

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  Map<String, dynamic> _cacheStats = {};
  List<UserPlaylist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = UserPlaylistService.getCacheStatistics();
      final playlists = UserPlaylistService.getUserPlaylists();

      setState(() {
        _cacheStats = stats;
        _playlists = playlists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Clear All Cache',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'CascadiaCode',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will clear all cached playlist songs. The data will be re-downloaded next time you view the playlists.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'CascadiaCode',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Clear Cache',
              style: TextStyle(
                color: AppColors.primary,
                fontFamily: 'CascadiaCode',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UserPlaylistService.clearAllPlaylistCaches();
      await _loadCacheInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All cache cleared successfully',
              style: TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  Future<void> _clearPlaylistCache(UserPlaylist playlist) async {
    await UserPlaylistService.clearPlaylistCache(playlist.playlistId);
    await _loadCacheInfo();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cache cleared for ${playlist.name}',
            style: const TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Cache Management',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadCacheInfo,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _clearAllCache,
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.red,
            ),
            tooltip: 'Clear All Cache',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadCacheInfo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCacheStatsCard(),
                  const SizedBox(height: 16),
                  _buildPlaylistCacheList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCacheStatsCard() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cache Statistics',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'CascadiaCode',
              ),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Total Playlists Cached', _cacheStats['totalPlaylistsCached']?.toString() ?? '0'),
            _buildStatRow('Total Songs Cached', _cacheStats['totalCachedSongs']?.toString() ?? '0'),
            _buildStatRow('Valid Caches', _cacheStats['validCaches']?.toString() ?? '0'),
            _buildStatRow('Expired Caches', _cacheStats['expiredCaches']?.toString() ?? '0'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'CascadiaCode',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontFamily: 'CascadiaCode',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCacheList() {
    if (_playlists.isEmpty) {
      return const Card(
        color: AppColors.surface,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No playlists found',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Playlist Caches',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _playlists.length,
            separatorBuilder: (context, index) => const Divider(
              color: AppColors.background,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final playlist = _playlists[index];
              final cacheInfo = UserPlaylistService.getPlaylistCacheInfo(playlist.playlistId);
              
              return ListTile(
                title: Text(
                  playlist.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: cacheInfo != null
                    ? Text(
                        '${cacheInfo['songsCount']} songs • ${cacheInfo['ageHours']}h old${cacheInfo['isExpired'] ? ' • Expired' : ''}',
                        style: TextStyle(
                          color: cacheInfo['isExpired'] ? Colors.orange : AppColors.textSecondary,
                          fontFamily: 'CascadiaCode',
                          fontSize: 12,
                        ),
                      )
                    : const Text(
                        'Not cached',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'CascadiaCode',
                          fontSize: 12,
                        ),
                      ),
                trailing: cacheInfo != null
                    ? IconButton(
                        onPressed: () => _clearPlaylistCache(playlist),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        tooltip: 'Clear Cache',
                      )
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
