import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'music_queue_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'liked_songs_page.dart';
import 'mini_music_player.dart';
import 'update_dialog.dart';
import '../services/liked_songs_service.dart';
import '../services/update_manager.dart';

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
