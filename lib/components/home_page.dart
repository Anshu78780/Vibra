import 'package:flutter/material.dart';
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
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    backgroundColor: const Color(0xFFB91C1C),
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(child: _pages[_currentIndex]),
          const MiniMusicPlayer(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Color(0xFF1A1A1A),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.black,
          selectedItemColor: const Color(0xFFB91C1C),
          unselectedItemColor: const Color(0xFF666666),
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline),
              activeIcon: Icon(Icons.favorite),
              label: 'Liked',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
