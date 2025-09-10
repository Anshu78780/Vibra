import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../controllers/music_player_controller.dart';
import '../components/universal_loader.dart';
import '../services/windows_media_service.dart';
import '../utils/app_colors.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenWidth < 360;
    
    // Responsive sizing
    final playerHeight = isTablet ? 80.0 : (isSmallScreen ? 68.0 : 72.0);
    final artworkSize = isTablet ? 60.0 : (isSmallScreen ? 48.0 : 52.0);
    final horizontalMargin = isTablet ? 20.0 : (isSmallScreen ? 8.0 : 12.0);
    final horizontalPadding = isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0);
    final verticalPadding = isTablet ? 12.0 : 10.0;
    final titleFontSize = isTablet ? 16.0 : (isSmallScreen ? 14.0 : 15.0);
    final artistFontSize = isTablet ? 14.0 : (isSmallScreen ? 12.0 : 13.0);
    final controlButtonSize = isTablet ? 26.0 : (isSmallScreen ? 20.0 : 22.0);
    final primaryButtonSize = isTablet ? 28.0 : (isSmallScreen ? 22.0 : 24.0);
    
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
        height: playerHeight,
        margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.backgroundLinearGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.cardBackground,
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
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: Row(
            children: [
              // Responsive album artwork with glow effect
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
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
                          width: artworkSize,
                          height: artworkSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: artworkSize,
                              height: artworkSize,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: AppColors.textMuted,
                                size: artworkSize * 0.45,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: artworkSize,
                          height: artworkSize,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.music_note_rounded,
                            color: AppColors.textMuted,
                            size: artworkSize * 0.45,
                          ),
                        ),
                ),
              ),
              SizedBox(width: isTablet ? 20 : 16),
              // Responsive track info with better typography
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _controller.currentTrack!.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: titleFontSize,
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
                        color: AppColors.textMuted,
                        fontSize: artistFontSize,
                        fontFamily: 'CascadiaCode',
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Enhanced responsive control buttons
              if (_controller.isLoading)
                Container(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: UniversalLoader(
                    size: isTablet ? 24 : 20,
                    showMessage: false,
                  ),
                )
              else if (_controller.errorMessage != null)
                GestureDetector(
                  onTap: () {
                    _controller.retry();
                  },
                  child: Container(
                    padding: EdgeInsets.all(isTablet ? 16 : 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: AppColors.warning,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.cardBackground,
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
                        size: controlButtonSize,
                      ),
                      SizedBox(width: isTablet ? 6 : 4),
                      // Play/Pause button (highlighted)
                      Container(
                        decoration: BoxDecoration(
                          gradient: _controller.canControl 
                              ? AppColors.primaryLinearGradient
                              : null,
                          color: _controller.canControl ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                          boxShadow: _controller.canControl ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 6,
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
                          size: primaryButtonSize,
                          isPrimary: true,
                        ),
                      ),
                      SizedBox(width: isTablet ? 6 : 4),
                      // Next button
                      _buildControlButton(
                        icon: Icons.skip_next_rounded,
                        onTap: _controller.hasNext && _controller.canControl
                            ? () => _controller.playNext()
                            : null,
                        isEnabled: _controller.hasNext && _controller.canControl,
                        size: controlButtonSize,
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
              ? (isPrimary ? AppColors.textPrimary : AppColors.textSecondary)
              : AppColors.textMuted,
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
              ? (isPrimary ? AppColors.textPrimary : AppColors.textSecondary)
              : AppColors.textMuted,
          size: size,
        ),
      ),
    );
  }
}
