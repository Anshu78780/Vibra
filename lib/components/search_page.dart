import 'package:flutter/material.dart';
import '../models/music_model.dart';
import '../services/music_service.dart';
import '../services/suggestion_service.dart';
import '../services/search_history_service.dart';
import '../controllers/music_player_controller.dart';
import 'dart:async';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<MusicTrack> _searchResults = [];
  List<String> _suggestions = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  bool _showHistory = false;
  String? _errorMessage;
  String _lastQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await SearchHistoryService.getRecentSearches(limit: 10);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _loadSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
      _showSuggestions = true;
    });

    try {
      final suggestions = await SuggestionService.getSuggestions(query);
      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
      print('Error loading suggestions: $e');
    }
  }

  void _onSearchTextChanged(String value) {
    _debounceTimer?.cancel();
    
    if (value.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _showHistory = true;
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _showHistory = false;
    });

    // Show suggestions after 300ms of no typing
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _searchController.text == value) {
        _loadSuggestions(value);
      }
    });
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    setState(() {
      _showSuggestions = false;
    });
    _performSearch(suggestion);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
        _lastQuery = '';
        _showSuggestions = false;
        _showHistory = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _lastQuery = query;
      _showSuggestions = false;
      _showHistory = false;
    });

    try {
      // Save to search history
      await SearchHistoryService.addToHistory(query);
      await _loadSearchHistory(); // Refresh history
      
      final response = await MusicService.searchMusic(query);
      setState(() {
        _searchResults = response.songs;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectFromHistory(String historyItem) {
    _searchController.text = historyItem;
    setState(() {
      _showHistory = false;
      _showSuggestions = false;
    });
    _performSearch(historyItem);
  }

  Future<void> _removeFromHistory(String historyItem) async {
    try {
      await SearchHistoryService.removeFromHistory(historyItem);
      await _loadSearchHistory(); // Refresh history
    } catch (e) {
      print('Error removing from history: $e');
    }
  }

  Future<void> _clearSearchHistory() async {
    try {
      await SearchHistoryService.clearHistory();
      await _loadSearchHistory(); // Refresh history
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Hide suggestions when tapping outside
        if (_showSuggestions || _showHistory) {
          setState(() {
            _showSuggestions = false;
            _showHistory = false;
          });
        }
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Search',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search for music...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF666666),
                      fontFamily: 'monospace',
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF666666),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF666666)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _showSuggestions = false;
                                _showHistory = true;
                                _searchResults = [];
                                _suggestions = [];
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _showSuggestions = false;
                    });
                    _performSearch(value);
                  },
                  onChanged: _onSearchTextChanged,
                  onTap: () {
                    if (_searchController.text.isEmpty) {
                      setState(() {
                        _showHistory = true;
                        _showSuggestions = false;
                      });
                    } else if (_suggestions.isNotEmpty) {
                      setState(() {
                        _showSuggestions = true;
                        _showHistory = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Suggestions or Search results or placeholder content
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Show search history when no search text and history is requested
    if (_showHistory && _searchController.text.isEmpty && _searchHistory.isNotEmpty) {
      return _buildSearchHistory();
    }
    
    // Show suggestions when typing and we have suggestions
    if (_showSuggestions && (_suggestions.isNotEmpty || _isLoadingSuggestions)) {
      return _buildSuggestions();
    }
    
    if (_isSearching) {
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
              'Searching...',
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
                'Search failed',
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
                onPressed: () => _performSearch(_lastQuery),
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

    if (_searchResults.isNotEmpty) {
      return _buildSearchResults();
    }

    return _buildEmptyState();
  }

  Widget _buildSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Text(
            'Search suggestions',
            style: TextStyle(
              color: Color(0xFF999999),
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Expanded(
          child: _isLoadingSuggestions
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFB91C1C),
                    strokeWidth: 2,
                  ),
                )
              : ListView.builder(
                  itemCount: _suggestions.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return GestureDetector(
                      onTap: () => _selectSuggestion(suggestion),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFF1A1A1A),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: Color(0xFF666666),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                suggestion,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.north_west,
                              color: Color(0xFF666666),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent searches',
                style: TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
              if (_searchHistory.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearchHistory,
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final historyItem = _searchHistory[index];
              return GestureDetector(
                onTap: () => _selectFromHistory(historyItem),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFF1A1A1A),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history,
                        color: Color(0xFF666666),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          historyItem,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeFromHistory(historyItem),
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFF666666),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Color(0xFF333333),
          ),
          SizedBox(height: 16),
          Text(
            'Search for music',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Find your favorite songs and artists',
            style: TextStyle(
              color: Color(0xFF444444),
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Text(
            'Found ${_searchResults.length} results for "$_lastQuery"',
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final track = _searchResults[index];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMusicTile(track),
                  if (index < _searchResults.length - 1)
                    const Divider(
                      color: Color(0xFF1A1A1A),
                      height: 1,
                      thickness: 0.5,
                      indent: 88,
                    ),
                ],
              );
            },
          ),
        ),
      ],
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
    final trackIndex = _searchResults.indexWhere((t) => t.webpageUrl == track.webpageUrl);
    if (trackIndex != -1 && _searchResults.isNotEmpty) {
      // Play the track and set up the search results as queue
      MusicPlayerController().playTrackFromQueue(_searchResults, trackIndex);
    } else {
      // Fallback to single track play
      MusicPlayerController().playTrack(track);
    }
  }
}
