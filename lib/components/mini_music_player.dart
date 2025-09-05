import 'package:flutter/material.dart';
import '../controllers/music_player_controller.dart';
import '../components/universal_loader.dart';
import 'full_music_player.dart';

class MiniMusicPlayer extends StatefulWidget {
  const MiniMusicPlayer({super.key});

  @override
  State<MiniMusicPlayer> createState() => _MiniMusicPlayerState();
}

class _MiniMusicPlayerState extends State<MiniMusicPlayer> {
  final MusicPlayerController _controller = MusicPlayerController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChanged);
    super.dispose();
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.hasTrack) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FullMusicPlayer(),
          ),
        );
      },
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          border: Border(
            top: BorderSide(
              color: Color(0xFF1A1A1A),
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Album artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _controller.currentTrack!.thumbnail.isNotEmpty
                    ? Image.network(
                        _controller.currentTrack!.thumbnail,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFF2C2C2E),
                            child: const Icon(
                              Icons.music_note,
                              color: Color(0xFF666666),
                              size: 20,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Color(0xFF666666),
                          size: 20,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _controller.currentTrack!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _controller.currentTrack!.artist,
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Loading or play/pause button
              if (_controller.isLoading)
                const UniversalLoader(
                  size: 24,
                  showMessage: false,
                )
              else
                GestureDetector(
                  onTap: () {
                    if (_controller.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.resume();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _controller.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
