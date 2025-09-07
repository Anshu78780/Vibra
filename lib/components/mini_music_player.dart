import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../controllers/music_player_controller.dart';
import '../components/universal_loader.dart';
import '../services/windows_media_service.dart';
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

    // Return Windows-specific compact layout
    if (Platform.isWindows) {
      return _buildWindowsMiniPlayer();
    }

    // Default mobile layout
    return _buildMobileMiniPlayer();
  }

  Widget _buildWindowsMiniPlayer() {
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
        width: double.infinity,
        height: 48,
        margin: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A2A2E),
              Color(0xFF1C1C1E),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF3A3A3E),
            width: 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            // Smaller album artwork
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    blurRadius: 3,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _controller.currentTrack!.thumbnail.isNotEmpty
                    ? Image.network(
                        _controller.currentTrack!.thumbnail,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3A3A3E), Color(0xFF2C2C2E)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Color(0xFF999999),
                              size: 16,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3A3A3E), Color(0xFF2C2C2E)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFF999999),
                          size: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            // Compact track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _controller.currentTrack!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'CascadiaCode',
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _controller.currentTrack!.artist,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                      fontFamily: 'CascadiaCode',
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Compact controls
            if (_controller.isLoading)
              Container(
                padding: const EdgeInsets.all(6),
                child: const UniversalLoader(
                  size: 14,
                  showMessage: false,
                ),
              )
            else if (_controller.errorMessage != null)
              GestureDetector(
                onTap: () {
                  _controller.retry();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.orange,
                    size: 14,
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Previous button
                  _buildCompactControlButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: _controller.hasPrevious && _controller.canControl
                        ? () => _controller.playPrevious()
                        : null,
                    isEnabled: _controller.hasPrevious && _controller.canControl,
                    size: 16,
                  ),
                  const SizedBox(width: 3),
                  // Play/Pause button
                  Container(
                    decoration: BoxDecoration(
                      gradient: _controller.canControl 
                          ? const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF991B1B)],
                            )
                          : null,
                      color: _controller.canControl ? null : const Color(0xFF4A4A4E),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _controller.canControl ? [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ] : null,
                    ),
                    child: _buildCompactControlButton(
                      icon: _controller.isPlaying 
                          ? Icons.pause_rounded 
                          : Icons.play_arrow_rounded,
                      onTap: _controller.canControl ? () {
                        if (_controller.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.resume();
                          // Ensure Windows SMTC shows after resume
                          if (Platform.isWindows) {
                            Future.delayed(const Duration(milliseconds: 500), () {
                              WindowsMediaService.instance.forceShow();
                            });
                          }
                        }
                      } : null,
                      isEnabled: _controller.canControl,
                      size: 18,
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 3),
                  // Next button
                  _buildCompactControlButton(
                    icon: Icons.skip_next_rounded,
                    onTap: _controller.hasNext && _controller.canControl
                        ? () => _controller.playNext()
                        : null,
                    isEnabled: _controller.hasNext && _controller.canControl,
                    size: 16,
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
  }
  

  Widget _buildMobileMiniPlayer() {
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
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A2A2E),
              Color(0xFF1C1C1E),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3A3A3E),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Album artwork with glow effect
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _controller.currentTrack!.thumbnail.isNotEmpty
                      ? Image.network(
                          _controller.currentTrack!.thumbnail,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3A3A3E), Color(0xFF2C2C2E)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: Color(0xFF999999),
                                size: 24,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3A3A3E), Color(0xFF2C2C2E)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Color(0xFF999999),
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Track info with better typography
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _controller.currentTrack!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'CascadiaCode',
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _controller.currentTrack!.artist,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontFamily: 'CascadiaCode',
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Enhanced control buttons with better styling
              if (_controller.isLoading)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3E).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const UniversalLoader(
                    size: 20,
                    showMessage: false,
                  ),
                )
              else if (_controller.errorMessage != null)
                GestureDetector(
                  onTap: () {
                    _controller.retry();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2E).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF3A3A3E),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Previous button
                      _buildControlButton(
                        icon: Icons.skip_previous_rounded,
                        onTap: _controller.hasPrevious && _controller.canControl
                            ? () => _controller.playPrevious()
                            : null,
                        isEnabled: _controller.hasPrevious && _controller.canControl,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      // Play/Pause button (highlighted)
                      Container(
                        decoration: BoxDecoration(
                          gradient: _controller.canControl 
                              ? const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF991B1B)],
                                )
                              : null,
                          color: _controller.canControl ? null : const Color(0xFF4A4A4E),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _controller.canControl ? [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ] : null,
                        ),
                        child: _buildControlButton(
                          icon: _controller.isPlaying 
                              ? Icons.pause_rounded 
                              : Icons.play_arrow_rounded,
                          onTap: _controller.canControl ? () {
                            if (_controller.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.resume();
                              // Ensure Windows SMTC shows after resume
                              if (Platform.isWindows) {
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  WindowsMediaService.instance.forceShow();
                                });
                              }
                            }
                          } : null,
                          isEnabled: _controller.canControl,
                          size: 24,
                          isPrimary: true,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Next button
                      _buildControlButton(
                        icon: Icons.skip_next_rounded,
                        onTap: _controller.hasNext && _controller.canControl
                            ? () => _controller.playNext()
                            : null,
                        isEnabled: _controller.hasNext && _controller.canControl,
                        size: 22,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactControlButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isEnabled,
    required double size,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isPrimary ? 6 : 4),
        child: Icon(
          icon,
          color: isEnabled 
              ? (isPrimary ? Colors.white : Colors.white.withOpacity(0.9))
              : Colors.white.withOpacity(0.3),
          size: size,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isEnabled,
    required double size,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isPrimary ? 10 : 8),
        child: Icon(
          icon,
          color: isEnabled 
              ? (isPrimary ? Colors.white : Colors.white.withOpacity(0.9))
              : Colors.white.withOpacity(0.3),
          size: size,
        ),
      ),
    );
  }
}
