import 'package:flutter/material.dart';
import 'dart:async';
import '../services/music_network_client.dart';
import '../utils/app_colors.dart';

class RemotePlayerPage extends StatefulWidget {
  final MusicNetworkClient client;

  const RemotePlayerPage({
    super.key,
    required this.client,
  });

  @override
  State<RemotePlayerPage> createState() => _RemotePlayerPageState();
}

class _RemotePlayerPageState extends State<RemotePlayerPage> with TickerProviderStateMixin {
  late Timer _updateTimer;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    
    // Start real-time updates with faster interval for better responsiveness
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        widget.client.updateRemoteStatus();
        setState(() {});
        
        // Rotate album art if playing
        if (widget.client.remoteIsPlaying) {
          if (!_rotationController.isAnimating) {
            _rotationController.repeat();
          }
        } else {
          _rotationController.stop();
        }
      }
    });

    // Initial update
    widget.client.updateRemoteStatus();
    widget.client.updateRemoteQueue();
    
    if (widget.client.remoteIsPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Remote Player - ${widget.client.connectedDevice?.name ?? "Unknown"}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
          ),
        ),
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await widget.client.updateRemoteQueue();
              await widget.client.updateRemoteStatus();
              if (mounted) {
                setState(() {});
              }
            },
            icon: const Icon(Icons.refresh),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Queue Section
          Expanded(
            child: _buildQueueSection(),
          ),
        ],
      ),
      bottomNavigationBar: widget.client.remoteCurrentTrack != null
          ? _buildMiniRemotePlayer()
          : null,
    );
  }

  Widget _buildMiniRemotePlayer() {
    final track = widget.client.remoteCurrentTrack!;
    
    return Container(
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
            // Album artwork with rotation
            RotationTransition(
              turns: _rotationController,
              child: Container(
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
                  child: Image.network(
                    track.thumbnail,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
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
              ),
            ),
            const SizedBox(width: 16),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.title,
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
                    track.artist,
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
            // Control buttons
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
                  _buildMiniControlButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: () async {
                      await widget.client.remotePrevious();
                      await widget.client.updateRemoteStatus();
                      if (mounted) setState(() {});
                    },
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  // Play/Pause button
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF991B1B)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: _buildMiniControlButton(
                      icon: widget.client.remoteIsPlaying 
                          ? Icons.pause_rounded 
                          : Icons.play_arrow_rounded,
                      onTap: () async {
                        if (widget.client.remoteIsPlaying) {
                          await widget.client.remotePause();
                        } else {
                          await widget.client.remotePlay();
                        }
                        await widget.client.updateRemoteStatus();
                        if (mounted) {
                          setState(() {});
                          // Update rotation animation immediately
                          if (widget.client.remoteIsPlaying) {
                            if (!_rotationController.isAnimating) {
                              _rotationController.repeat();
                            }
                          } else {
                            _rotationController.stop();
                          }
                        }
                      },
                      size: 24,
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Next button
                  _buildMiniControlButton(
                    icon: Icons.skip_next_rounded,
                    onTap: () async {
                      await widget.client.remoteNext();
                      await widget.client.updateRemoteStatus();
                      if (mounted) setState(() {});
                    },
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isPrimary ? 10 : 8),
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.9),
          size: size,
        ),
      ),
    );
  }

  Widget _buildQueueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.queue_music,
                color: AppColors.secondary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Queue',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.client.remoteQueue.length} tracks',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: widget.client.remoteQueue.isNotEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.client.remoteQueue.length,
                  itemBuilder: (context, index) {
                    final track = widget.client.remoteQueue[index];
                    final isCurrentTrack = index == widget.client.remoteCurrentIndex;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isCurrentTrack 
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrentTrack 
                            ? Border.all(color: AppColors.primary.withOpacity(0.3))
                            : null,
                      ),
                      child: ListTile(
                        onTap: () async {
                          // Play from queue if method exists
                          try {
                            await widget.client.remotePlayFromQueue(index);
                            // Immediately update UI and queue
                            await widget.client.updateRemoteStatus();
                            await widget.client.updateRemoteQueue();
                            if (mounted) {
                              setState(() {});
                              
                              // Update rotation animation immediately
                              if (widget.client.remoteIsPlaying) {
                                if (!_rotationController.isAnimating) {
                                  _rotationController.repeat();
                                }
                              } else {
                                _rotationController.stop();
                              }
                            }
                          } catch (e) {
                            // Method might not exist, show snackbar
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot play from queue: ${e.toString()}'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            track.thumbnail,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.music_note, 
                                  color: AppColors.textMuted, size: 24),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            if (isCurrentTrack) ...[
                              Icon(
                                widget.client.remoteIsPlaying ? Icons.play_arrow : Icons.pause,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                track.title,
                                style: TextStyle(
                                  color: isCurrentTrack 
                                      ? AppColors.primary 
                                      : AppColors.textPrimary,
                                  fontWeight: isCurrentTrack 
                                      ? FontWeight.w600 
                                      : FontWeight.normal,
                                  fontFamily: 'CascadiaCode',
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          track.artist,
                          style: TextStyle(
                            color: isCurrentTrack 
                                ? AppColors.primary.withOpacity(0.8)
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontFamily: 'CascadiaCode',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCurrentTrack 
                                ? AppColors.primary 
                                : AppColors.textMuted,
                            fontSize: 14,
                            fontFamily: 'CascadiaCode',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                )
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music,
                          color: AppColors.textMuted,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No tracks in queue',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontFamily: 'CascadiaCode',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

}
