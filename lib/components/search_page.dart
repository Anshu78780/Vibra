import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../models/music_model.dart';
import '../services/youtube_search_service.dart';
import '../services/search_history_service.dart';
import '../controllers/music_player_controller.dart';
import '../utils/app_colors.dart';
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
      final suggestions = await YoutubeSearchService.getSuggestions(query);
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
      
      final searchResponse = await YoutubeSearchService.searchMusic(query);
      setState(() {
        _searchResults = searchResponse.songs;
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text(
            'Search',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontFamily: 'CascadiaCode',
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.cardBackground,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search for music...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontFamily: 'CascadiaCode',
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showSuggestions = false;
                                  _showHistory = true;
                                  _searchResults = [];
                                  _suggestions = [];
                                });
                              },
                              hoverColor: AppColors.cardBackground.withOpacity(0.5),
                              splashColor: AppColors.primary.withOpacity(0.2),
                            ),
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
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'CascadiaCode',
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
              const Icon(Icons.error, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Search failed',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontFamily: 'CascadiaCode',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  onPressed: () => _performSearch(_lastQuery),
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontFamily: 'CascadiaCode'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ).copyWith(
                    overlayColor: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.hovered)) {
                          return AppColors.primaryDark;
                        }
                        return null;
                      },
                    ),
                  ),
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
          child: Row(
            children: [
              Icon(
                Icons.youtube_searched_for,
                color: AppColors.primary,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'YouTube suggestions',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingSuggestions
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                )
              : ListView.builder(
                  itemCount: _suggestions.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return _HoverableListTile(
                      onTap: () => _selectSuggestion(suggestion),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.cardBackground,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                suggestion,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontFamily: 'CascadiaCode',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.north_west,
                              color: AppColors.textMuted,
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
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              if (_searchHistory.isNotEmpty)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _clearSearchHistory,
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontFamily: 'CascadiaCode',
                      ),
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
              return _HoverableListTile(
                onTap: () => _selectFromHistory(historyItem),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.cardBackground,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          historyItem,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontFamily: 'CascadiaCode',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _removeFromHistory(historyItem),
                          child: const Icon(
                            Icons.close,
                            color: AppColors.textMuted,
                            size: 16,
                          ),
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
            color: AppColors.cardBackground,
          ),
          SizedBox(height: 16),
          Text(
            'Search for music',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontFamily: 'CascadiaCode',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Find your favorite songs and artists',
            style: TextStyle(
              color: Color(0xFF6B7280), // Slightly more muted gray
              fontSize: 14,
              fontFamily: 'CascadiaCode',
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
              color: AppColors.textMuted,
              fontSize: 14,
              fontFamily: 'CascadiaCode',
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
                      color: AppColors.cardBackground,
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
    return _HoverableListTile(
      onTap: () => _playTrack(track),
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
            // More options button
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showTrackOptions(track),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.more_vert,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ListTile(
                leading: const Icon(Icons.play_arrow, color: AppColors.textPrimary),
                title: const Text(
                  'Play', 
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _playTrack(track);
                },
                hoverColor: AppColors.cardBackground.withOpacity(0.5),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ListTile(
                leading: const Icon(Icons.favorite_border, color: AppColors.textPrimary),
                title: const Text(
                  'Like', 
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                onTap: () => Navigator.pop(context),
                hoverColor: AppColors.cardBackground.withOpacity(0.5),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ListTile(
                leading: const Icon(Icons.share, color: AppColors.textPrimary),
                title: const Text(
                  'Share', 
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                onTap: () => Navigator.pop(context),
                hoverColor: AppColors.cardBackground.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playTrack(MusicTrack track) {
    // Use recommendations instead of search results as queue for better suggestions
    MusicPlayerController().playTrackWithRecommendations(track);
  }
}

// Hoverable list tile widget for Windows hover effects
class _HoverableListTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HoverableListTile({
    required this.child,
    required this.onTap,
  });

  @override
  State<_HoverableListTile> createState() => _HoverableListTileState();
}

class _HoverableListTileState extends State<_HoverableListTile> {
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
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered 
                ? AppColors.surface.withOpacity(0.8)
                : Colors.transparent,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
