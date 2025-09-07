import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'About',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Name and Version
            const Center(
              child: Text(
                'Vibra',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
            const Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textMuted,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // ScreenScape Group Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBackground),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Part of ScreenScape Group',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        fontFamily: 'CascadiaCode',
                      ),
                      children: [
                        const TextSpan(
                          text: 'Try ScreenScape - our free movie streaming app at ',
                        ),
                        TextSpan(
                          text: 'www.screenscape.fun',
                          style: const TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _launchURL('https://www.screenscape.fun'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: () => _launchURL('https://www.screenscape.fun'),
                    icon: const Icon(Icons.download),
                    label: const Text('Download ScreenScape'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontFamily: 'CascadiaCode',
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            
            // Features Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBackground),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Features',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    icon: Icons.music_note,
                    title: 'Music Streaming',
                    description: 'Stream music with high quality audio playback',
                  ),
                  _buildFeatureItem(
                    icon: Icons.playlist_play,
                    title: 'Smart Playlists',
                    description: 'Create and manage personalized playlists',
                  ),
                  _buildFeatureItem(
                    icon: Icons.history,
                    title: 'Listening History',
                    description: 'Track your listening habits and statistics',
                  ),
                  _buildFeatureItem(
                    icon: Icons.download,
                    title: 'Offline Mode',
                    description: 'Download music for offline listening',
                  ),
                  _buildFeatureItem(
                    icon: Icons.auto_awesome,
                    title: 'Recommendations',
                    description: 'Get personalized music recommendations',
                  ),
                  _buildFeatureItem(
                    icon: Icons.sync,
                    title: 'Cross-Platform Support',
                    description: 'Use on Windows, Android, iOS and more',
                    isLast: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            
            // Open Source Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBackground),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open Source',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vibra is an open source project. Your contributions help make it better for everyone.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _launchURL('https://github.com/Anshu78780'),
                          icon: const Icon(Icons.star),
                          label: const Text('Star Project'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontFamily: 'CascadiaCode',
                              fontWeight: FontWeight.w500,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _launchURL('https://github.com/Anshu78780'),
                          icon: const Icon(Icons.code),
                          label: const Text('Contribute'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontFamily: 'CascadiaCode',
                              fontWeight: FontWeight.w500,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            
            // Copyright Information
            const Center(
              child: Text(
                '© 2025 ScreenScape Group',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
            const Center(
              child: Text(
                'All Rights Reserved',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(
          bottom: BorderSide(
            color: AppColors.cardBackground,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
