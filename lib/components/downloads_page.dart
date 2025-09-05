import 'package:flutter/material.dart';
import '../models/music_model.dart';
import '../services/download_service.dart';
import '../controllers/music_player_controller.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDownloadedTracks();
    _setupDownloadProgressListener();
  }

  void _setupDownloadProgressListener() {
    _downloadService.downloadProgressStream.listen((progress) {
      setState(() {
        _downloadProgress = progress;
      });
    });
  }

  Future<void> _loadDownloadedTracks() async {
    try {
      final tracks = await _downloadService.getDownloadedTracks();
      setState(() {
        _downloadedTracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading downloaded tracks: $e');
      setState(() {
        _isLoading = false;
      });
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
              style: const TextStyle(fontFamily: 'monospace'),
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
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
            fontFamily: 'monospace',
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_downloadedTracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _showClearAllDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB91C1C)),
              ),
            )
          : _downloadedTracks.isEmpty
              ? _buildEmptyState()
              : _buildDownloadsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download songs to listen offline',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB91C1C)),
                      backgroundColor: Colors.grey[700],
                    )
                  : const Icon(
                      Icons.music_note,
                      color: Color(0xFFB91C1C),
                      size: 28,
                    ),
            ),
            title: Text(
              track.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
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
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (progress != null && progress < 1.0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Downloading ${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                      fontFamily: 'monospace',
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB91C1C)),
                    ),
                  )
                : PopupMenuButton<String>(
                    color: const Color(0xFF2C2C2E),
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      if (value == 'play') {
                        MusicPlayerController().playTrack(track);
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
                                fontFamily: 'monospace',
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
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            onTap: progress == null || progress >= 1.0
                ? () {
                    MusicPlayerController().playTrack(track);
                    Navigator.pop(context);
                  }
                : null,
          ),
        );
      },
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
            fontFamily: 'monospace',
          ),
        ),
        content: const Text(
          'Are you sure you want to delete all downloaded songs?',
          style: TextStyle(
            color: Color(0xFF999999),
            fontFamily: 'monospace',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF999999),
                fontFamily: 'monospace',
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
                      style: TextStyle(fontFamily: 'monospace'),
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
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
