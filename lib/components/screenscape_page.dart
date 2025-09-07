import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';

class ScreenscapePage extends StatelessWidget {
  const ScreenscapePage({super.key});

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
          'ScreenScape',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.2,
                      child: Image.network(
                        'https://images.unsplash.com/photo-1616530940355-351fabd9524b?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1350&q=80',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'ScreenScape',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Premium Streaming Experience',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _launchURL('https://www.screenscape.fun'),
                          icon: const Icon(Icons.download),
                          label: const Text('Download Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'CascadiaCode',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About ScreenScape
                  const SectionHeading(title: 'About ScreenScape'),
                  const SizedBox(height: 12),
                  const Text(
                    'ScreenScape is a premium streaming platform offering access to the latest movies and TV shows from over 30+ providers including Netflix, Prime Video, Disney+, and more. Enjoy high-quality streaming with our intuitive and elegant interface.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Key Features
                  const SectionHeading(title: 'Key Features'),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    icon: Icons.high_quality,
                    title: '4K Quality Streaming',
                    description: 'Watch content in stunning ultra-high definition.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.storage_rounded,
                    title: '30+ Content Providers',
                    description: 'Access content from Netflix, Prime Video, and many more.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.download_rounded,
                    title: 'Download Support',
                    description: 'Download movies and shows for offline viewing.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.playlist_add_check,
                    title: 'Request Content',
                    description: 'Request specific movies or shows you want to watch.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.notifications_active,
                    title: 'New Release Alerts',
                    description: 'Get notified when new content becomes available.',
                    isLast: true,
                  ),
                  const SizedBox(height: 24),

                  // Testimonials
                  const SectionHeading(title: 'What Users Say'),
                  const SizedBox(height: 12),
                  _buildTestimonial(
                    quote: '"The best streaming app I\'ve ever used. So much content in one place!"',
                    author: 'Sarah K.',
                    rating: 5,
                  ),
                  _buildTestimonial(
                    quote: '"The 4K quality is amazing, and I love being able to download movies for my commute."',
                    author: 'Michael T.',
                    rating: 5,
                  ),
                  _buildTestimonial(
                    quote: '"Having access to so many providers in one app is a game changer."',
                    author: 'James L.',
                    rating: 5,
                    isLast: true,
                  ),
                  const SizedBox(height: 24),

                  // Download CTA
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Ready to Elevate Your Streaming Experience?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Join thousands of satisfied users enjoying premium content today.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _launchURL('https://www.screenscape.fun'),
                          icon: const Icon(Icons.download),
                          label: const Text('Download ScreenScape'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'CascadiaCode',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontFamily: 'CascadiaCode',
                            ),
                            children: [
                              const TextSpan(text: 'Visit '),
                              TextSpan(
                                text: 'www.screenscape.fun',
                                style: const TextStyle(
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchURL('https://www.screenscape.fun'),
                              ),
                              const TextSpan(text: ' for more information'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(
            color: AppColors.cardBackground.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
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

  Widget _buildTestimonial({
    required String quote,
    required String author,
    required int rating,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.cardBackground,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontStyle: FontStyle.italic,
              fontFamily: 'CascadiaCode',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                author,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: index < rating ? Colors.amber : Colors.grey,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;

  const SectionHeading({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
          ),
        ),
      ],
    );
  }
}
