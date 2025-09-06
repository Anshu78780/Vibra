import 'package:flutter/material.dart';
import '../services/song_history_service.dart';
import '../controllers/music_player_controller.dart';
import '../models/music_model.dart';

class SongHistoryPage extends StatefulWidget {
  const SongHistoryPage({super.key});

  @override
  State<SongHistoryPage> createState() => _SongHistoryPageState();
}

class _SongHistoryPageState extends State<SongHistoryPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final SongHistoryService _historyService = SongHistoryService();
  final MusicPlayerController _playerController = MusicPlayerController();
  final TextEditingController _searchController = TextEditingController();
  
  List<HistoryEntry> _allHistory = [];
  List<HistoryEntry> _filteredHistory = [];
  List<HistoryEntry> _recentHistory = [];
  List<HistoryEntry> _todayHistory = [];
  List<Map<String, dynamic>> _mostPlayed = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHistoryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allHistory = await _historyService.getHistoryEntries();
      final recentHistory = await _historyService.getRecentlyPlayed(limit: 100);
      final todayHistory = await _historyService.getTodaysHistory();
      final mostPlayed = await _historyService.getMostPlayedSongs(limit: 50);
      final stats = await _historyService.getHistoryStats();

      setState(() {
        _allHistory = allHistory;
        _filteredHistory = allHistory;
        _recentHistory = recentHistory;
        _todayHistory = todayHistory;
        _mostPlayed = mostPlayed;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterHistory(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredHistory = _allHistory;
      } else {
        _filteredHistory = _allHistory.where((entry) {
          final track = entry.track;
          return track.title.toLowerCase().contains(query.toLowerCase()) ||
                 track.artist.toLowerCase().contains(query.toLowerCase()) ||
                 track.album.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _playTrack(MusicTrack track) async {
    try {
      await _playerController.playTrack(track);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing ${track.title}'),
          backgroundColor: const Color(0xFF7B68EE),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing track: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeFromHistory(String entryId) async {
    try {
      await _historyService.removeFromHistory(entryId);
      await _loadHistoryData(); // Refresh the data
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from history'),
          backgroundColor: Color(0xFF7B68EE),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing from history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRemoveDialog(String entryId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove from History', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Remove this song from your listening history?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeFromHistory(entryId);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear History', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to clear all listening history? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _historyService.clearHistory();
        await _loadHistoryData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History cleared'),
            backgroundColor: Color(0xFF7B68EE),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final songDate = DateTime(date.year, date.month, date.day);

    if (songDate == today) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (songDate == yesterday) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildHistoryItem(HistoryEntry entry, {bool showDate = true, bool showRemove = true}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: const Color(0xFF7B68EE).withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: entry.track.thumbnail.isNotEmpty
                ? Image.network(
                    entry.track.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.music_note,
                      color: Color(0xFF7B68EE),
                      size: 20,
                    ),
                  )
                : const Icon(
                    Icons.music_note,
                    color: Color(0xFF7B68EE),
                    size: 20,
                  ),
          ),
        ),
        title: Text(
          entry.track.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              entry.track.artist,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showDate) ...[
              const SizedBox(height: 2),
              Text(
                _formatDate(entry.playedAt),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Color(0xFF7B68EE), size: 20),
              onPressed: () => _playTrack(entry.track),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(6),
            ),
            if (showRemove)
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
                onPressed: () => _showRemoveDialog(entry.id),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(6),
              ),
          ],
        ),
        onTap: () => _playTrack(entry.track),
      ),
    );
  }

  Widget _buildMostPlayedItem(Map<String, dynamic> item) {
    final track = item['track'] as MusicTrack;
    final playCount = item['playCount'] as int;
    final lastPlayed = item['lastPlayed'] as DateTime;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: const Color(0xFF7B68EE).withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: track.thumbnail.isNotEmpty
                ? Image.network(
                    track.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.music_note,
                      color: Color(0xFF7B68EE),
                      size: 20,
                    ),
                  )
                : const Icon(
                    Icons.music_note,
                    color: Color(0xFF7B68EE),
                    size: 20,
                  ),
          ),
        ),
        title: Text(
          track.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              track.artist,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B68EE).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$playCount plays',
                    style: const TextStyle(
                      color: Color(0xFF7B68EE),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Last: ${_formatDate(lastPlayed)}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_arrow, color: Color(0xFF7B68EE), size: 20),
          onPressed: () => _playTrack(track),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.all(6),
        ),
        onTap: () => _playTrack(track),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats.isEmpty) return const SizedBox.shrink();

    final totalPlays = _stats['totalPlays'] as int;
    final uniqueSongs = _stats['uniqueSongs'] as int;
    final totalListeningTime = _stats['totalListeningTime'] as int;
    final averagePerDay = _stats['averagePerDay'] as double;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B68EE), Color(0xFF9F7AEA)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B68EE).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Listening Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalPlays.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Total Plays',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uniqueSongs.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Unique Songs',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDuration(totalListeningTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Total Listening Time',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${averagePerDay.toStringAsFixed(1)} songs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Average per Day',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Listening History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF2A2A2A),
            onSelected: (value) {
              if (value == 'clear') {
                _clearAllHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear History', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7B68EE),
          labelColor: const Color(0xFF7B68EE),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Recent'),
            Tab(text: 'Today'),
            Tab(text: 'Most Played'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF7B68EE),
              ),
            )
          : Column(
              children: [
                // Search bar (only show for All tab)
                if (_tabController.index == 3)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterHistory,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search history...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterHistory('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                
                // Statistics card (only show for Most Played tab)
                if (_tabController.index == 2)
                  _buildStatsCard(),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Recent tab
                      _recentHistory.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No recent songs',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: _recentHistory.length,
                              itemBuilder: (context, index) {
                                return _buildHistoryItem(_recentHistory[index]);
                              },
                            ),
                      
                      // Today tab
                      _todayHistory.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No songs played today',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: _todayHistory.length,
                              itemBuilder: (context, index) {
                                return _buildHistoryItem(_todayHistory[index]);
                              },
                            ),
                      
                      // Most Played tab
                      _mostPlayed.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No frequently played songs',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: _mostPlayed.length,
                              itemBuilder: (context, index) {
                                return _buildMostPlayedItem(_mostPlayed[index]);
                              },
                            ),
                      
                      // All tab
                      _filteredHistory.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  _searchQuery.isNotEmpty 
                                      ? 'No songs found for "$_searchQuery"'
                                      : 'No listening history',
                                  style: const TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: _filteredHistory.length,
                              itemBuilder: (context, index) {
                                return _buildHistoryItem(_filteredHistory[index]);
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
