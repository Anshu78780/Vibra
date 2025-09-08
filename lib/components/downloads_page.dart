import 'package:flutter/material.dart';
import 'dart:async';
import '../models/music_model.dart';
import '../services/download_service.dart';
import '../controllers/music_player_controller.dart';
import 'mini_music_player.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final DownloadService _downloadService = DownloadService();
  List<MusicTrack> _downloadedTracks = [];
  Map<String, double> _downloadProgress = {};
  bool _isLoading = true;
  bool _isInitialLoad = true;
  StreamSubscription? _downloadProgressSubscription;

  @override
  void initState() {
    super.initState();
    _loadDownloadedTracks();
    _setupDownloadProgressListener();
  }

  @override
  void dispose() {
    _downloadProgressSubscription?.cancel();
    super.dispose();
  }

  void _setupDownloadProgressListener() {
    _downloadProgressSubscription = _downloadService.downloadProgressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
        });
      }
    });
  }

  Future<void> _loadDownloadedTracks() async {
    try {
      final tracks = await _downloadService.getDownloadedTracks();
      if (mounted) {
        setState(() {
          _downloadedTracks = tracks;
          _isLoading = false;
        });
        
        // Show refresh feedback only if not the initial load
        if (!_isInitialLoad) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Downloads refreshed • ${tracks.length} songs found',
                style: const TextStyle(fontFamily: 'CascadiaCode'),
              ),
              backgroundColor: const Color(0xFF1C1C1E),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        _isInitialLoad = false;
      }
    } catch (e) {
      print('Error loading downloaded tracks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (!_isInitialLoad) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to refresh downloads: $e',
                style: const TextStyle(fontFamily: 'CascadiaCode'),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _isInitialLoad = false;
      }
    }
  }

  Future<void> _deleteDownload(MusicTrack track) async {
    try {
      await _downloadService.deleteDownload(track);
      _loadDownloadedTracks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted ${track.title}',
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: const Color(0xFF1C1C1E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete: $e',
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _playTrackFromDownloads(MusicTrack track) {
    final trackIndex = _downloadedTracks.indexWhere((t) => t.webpageUrl == track.webpageUrl);
    if (trackIndex != -1) {
      // Play the track and set up the entire downloaded songs queue
      MusicPlayerController().playTrackFromQueue(_downloadedTracks, trackIndex);
    } else {
      // Fallback to single track play
      MusicPlayerController().playTrack(track);
    }
  }

  void _playAllDownloads() {
    if (_downloadedTracks.isNotEmpty) {
      MusicPlayerController().playTrackFromQueue(_downloadedTracks, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Downloads',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDownloadedTracks,
            tooltip: 'Refresh Downloads',
          ),
          if (_downloadedTracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _showClearAllDialog,
              tooltip: 'Clear All Downloads',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDownloadedTracks,
        backgroundColor: const Color(0xFF1C1C1E),
        color: const Color(0xFF6366F1),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              )
            : _downloadedTracks.isEmpty
                ? _buildEmptyState()
                : _buildDownloadsList(),
      ),
      bottomNavigationBar: const MiniMusicPlayer(),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 200, // Account for AppBar and bottom nav
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.download_outlined,
                size: 80,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No Downloaded Songs',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Download songs to listen offline',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pull down to refresh',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontFamily: 'CascadiaCode',
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadsList() {
    return Column(
      children: [
        // Play All button
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _downloadedTracks.isNotEmpty ? _playAllDownloads : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              'Play All (${_downloadedTracks.length} songs)',
              style: const TextStyle(
                fontFamily: 'CascadiaCode',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        // Songs list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _downloadedTracks.length,
            itemBuilder: (context, index) {
              final track = _downloadedTracks[index];
              final trackId = track.webpageUrl.split('v=').last;
              final progress = _downloadProgress[trackId];
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: progress != null && progress < 1.0
                        ? CircularProgressIndicator(
                            value: progress,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            backgroundColor: Colors.grey[700],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: track.thumbnail.isNotEmpty
                                ? Image.network(
                                    track.thumbnail,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
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
                                          color: Color(0xFF6366F1),
                                          size: 28,
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2C2C2E),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons.music_note,
                                    color: Color(0xFF6366F1),
                                    size: 28,
                                  ),
                          ),
                  ),
            title: Text(
              track.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
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
                  track.artist,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 14,
                    fontFamily: 'CascadiaCode',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (progress != null && progress < 1.0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Downloading ${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 12,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                ],
              ],
            ),
            trailing: progress != null && progress < 1.0
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  )
                : PopupMenuButton<String>(
                    color: const Color(0xFF2C2C2E),
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      if (value == 'play') {
                        _playTrackFromDownloads(track);
                        Navigator.pop(context);
                      } else if (value == 'delete') {
                        _deleteDownload(track);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'play',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Play',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'CascadiaCode',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.red,
                                fontFamily: 'CascadiaCode',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            onTap: progress == null || progress >= 1.0
                ? () {
                    _playTrackFromDownloads(track);
                    Navigator.pop(context);
                  }
                : null,
          ),
        );
      },
    ),
        ),
      ],
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Clear All Downloads',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'CascadiaCode',
          ),
        ),
        content: const Text(
          'Are you sure you want to delete all downloaded songs?',
          style: TextStyle(
            color: Color(0xFF999999),
            fontFamily: 'CascadiaCode',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF999999),
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _downloadService.clearAllDownloads();
              _loadDownloadedTracks();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'All downloads cleared',
                      style: TextStyle(fontFamily: 'CascadiaCode'),
                    ),
                    backgroundColor: Color(0xFF1C1C1E),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Delete All',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
