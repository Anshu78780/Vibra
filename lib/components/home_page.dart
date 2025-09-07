import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'music_queue_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'liked_songs_page.dart';
import 'mini_music_player.dart';
import 'full_music_player.dart';
import 'update_dialog.dart';
import '../services/liked_songs_service.dart';
import '../services/update_manager.dart';
import '../controllers/music_player_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const MusicQueuePage(),
    const SearchPage(),
    const LikedSongsPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadLikedSongs();
    _checkForUpdates();
  }
  
  Future<void> _loadLikedSongs() async {
    // Load liked songs from cache when app starts
    await LikedSongsService.loadCachedLikedSongs();
  }

  Future<void> _checkForUpdates() async {
    try {
      // Check if enough time has passed since last update check
      final shouldCheck = await UpdateManager.shouldCheckForUpdates();
      if (!shouldCheck) return;

      // Check for updates
      final updateInfo = await UpdateManager.checkForUpdates();
      if (updateInfo != null && mounted) {
        // Show update dialog
        await UpdateDialog.show(
          context,
          updateInfo,
          onSkip: () async {
            await UpdateManager.skipVersion(updateInfo.latestVersion);
          },
          onLater: () {
            // Do nothing, will check again next time
          },
          onUpdate: () async {
            try {
              await UpdateManager.downloadUpdate(updateInfo.downloadUrl);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to open download link: $e',
                      style: const TextStyle(fontFamily: 'CascadiaCode'),
                    ),
                    backgroundColor: const Color(0xFF6366F1),
                  ),
                );
              }
            }
          },
        );
      }
    } catch (e) {
      print('Error checking for updates: $e');
      // Silently fail - don't interrupt user experience
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      return _buildWindowsLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // Build the spinning mini player for the sidebar
  Widget _buildMiniPlayerForSidebar() {
    final playerController = MusicPlayerController();
    
    // If no track is playing, don't show anything
    if (!playerController.hasTrack) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: playerController,
      builder: (context, _) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FullMusicPlayer()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF1DB954).withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Spinning album cover with subtle hover effect
                      AnimatedOpacity(
                        opacity: playerController.isLoading ? 0.3 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: _AlbumArtContainer(
                          playerController: playerController,
                        ),
                      ),
                      
                      // Loading indicator overlay
                      if (playerController.isLoading)
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.3),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF1DB954),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Interactive Play/Pause button with hover effect
                  _PlayPauseButton(playerController: playerController),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWindowsLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Spotify-like dark background
      body: Row(
        children: [
          // Side Navigation Rail
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1E1E), // Darker gradient top
                  Color(0xFF191414), // Spotify dark
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: const Color(0xFF1DB954).withOpacity(0.1), // Spotify green with opacity
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIconTheme: const IconThemeData(
                      color: Color(0xFF1DB954), // Spotify green
                      size: 26,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: const Color(0xFFB3B3B3).withOpacity(0.7), // Spotify gray
                      size: 24,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: Color(0xFF1DB954), // Spotify green
                      fontFamily: 'CascadiaCode',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      color: const Color(0xFFB3B3B3).withOpacity(0.8),
                      fontFamily: 'CascadiaCode',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                    labelType: NavigationRailLabelType.all,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search_outlined),
                        selectedIcon: Icon(Icons.search_rounded),
                        label: Text('Search'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.favorite_border_rounded),
                        selectedIcon: Icon(Icons.favorite_rounded),
                        label: Text('Liked'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings_rounded),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                ),
                // Current song mini player at the bottom of sidebar
                _buildMiniPlayerForSidebar(),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E1E1E), // Darker at top
                    Color(0xFF121212), // Spotify dark at bottom
                  ],
                ),
              ),
              child: _pages[_currentIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Spotify dark background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1E1E), // Darker at top
              Color(0xFF121212), // Spotify dark at bottom
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(child: _pages[_currentIndex]),
            const MiniMusicPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF191414), // Spotify dark
              Color(0xFF0D0D0D), // Even darker
            ],
          ),
          border: Border(
            top: BorderSide(
              color: const Color(0xFF1DB954).withOpacity(0.1), // Spotify green with opacity
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF1DB954), // Spotify green
          unselectedItemColor: const Color(0xFFB3B3B3).withOpacity(0.7), // Spotify gray
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'CascadiaCode',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'CascadiaCode',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFB3B3B3).withOpacity(0.6),
          ),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border_rounded),
              activeIcon: Icon(Icons.favorite_rounded),
              label: 'Liked',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// Album art container with hover effects
class _AlbumArtContainer extends StatefulWidget {
  final MusicPlayerController playerController;

  const _AlbumArtContainer({required this.playerController});

  @override
  State<_AlbumArtContainer> createState() => _AlbumArtContainerState();
}

class _AlbumArtContainerState extends State<_AlbumArtContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: SpinningAlbumArt(
          isPlaying: widget.playerController.isPlaying,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1DB954).withOpacity(_isHovered ? 0.4 : 0.2),
                  blurRadius: _isHovered ? 12 : 8,
                  spreadRadius: _isHovered ? 2 : 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: widget.playerController.currentTrack!.thumbnail.isNotEmpty
                ? Image.network(
                    widget.playerController.currentTrack!.thumbnail,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFF2A2A2E),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFF1DB954),
                          size: 24,
                        ),
                      );
                    },
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFF2A2A2E),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFF1DB954),
                      size: 24,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

// Interactive Play/Pause button widget with hover effects
class _PlayPauseButton extends StatefulWidget {
  final MusicPlayerController playerController;

  const _PlayPauseButton({required this.playerController});

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (widget.playerController.isPlaying) {
            widget.playerController.pause();
          } else {
            widget.playerController.resume();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered 
                ? const Color(0xFF1DB954).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: _isHovered
                ? Border.all(
                    color: const Color(0xFF1DB954).withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: AnimatedScale(
            scale: _isHovered ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Icon(
              widget.playerController.isPlaying 
                  ? Icons.pause_rounded 
                  : Icons.play_arrow_rounded,
              color: _isHovered 
                  ? const Color(0xFF1ED760) 
                  : const Color(0xFF1DB954),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// Widget for spinning album art when a song is playing
class SpinningAlbumArt extends StatefulWidget {
  final bool isPlaying;
  final Widget child;

  const SpinningAlbumArt({
    Key? key,
    required this.isPlaying,
    required this.child,
  }) : super(key: key);

  @override
  State<SpinningAlbumArt> createState() => _SpinningAlbumArtState();
}

class _SpinningAlbumArtState extends State<SpinningAlbumArt> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    if (!widget.isPlaying) {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(SpinningAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: widget.child,
    );
  }
}
