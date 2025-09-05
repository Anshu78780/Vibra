import 'package:flutter/material.dart';
import 'music_queue_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'liked_songs_page.dart';
import 'mini_music_player.dart';
import '../services/liked_songs_service.dart';

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
  }
  
  Future<void> _loadLikedSongs() async {
    // Load liked songs from cache when app starts
    await LikedSongsService.loadCachedLikedSongs();
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
