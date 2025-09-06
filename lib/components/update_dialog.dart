import 'package:flutter/material.dart';
import '../services/update_manager.dart';
import '../utils/app_colors.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final VoidCallback? onSkip;
  final VoidCallback? onLater;
  final VoidCallback? onUpdate;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.onSkip,
    this.onLater,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: AppColors.cardBackground,
          width: 1,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.system_update,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update Available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                Text(
                  'v${updateInfo.latestVersion}',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 14,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF333333),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF666666),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current: v${updateInfo.currentVersion}',
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF666666),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Latest: v${updateInfo.latestVersion}',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 12,
                    fontFamily: 'CascadiaCode',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "What's New:",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'CascadiaCode',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF333333),
                width: 1,
              ),
            ),
            child: Text(
              updateInfo.releaseNotes.isNotEmpty 
                  ? updateInfo.releaseNotes
                  : 'Bug fixes and improvements',
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 13,
                fontFamily: 'CascadiaCode',
                height: 1.4,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1419),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF2A3B47),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info,
                  color: Color(0xFF4A90E2),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can continue using the app without updating',
                    style: const TextStyle(
                      color: Color(0xFF4A90E2),
                      fontSize: 11,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onSkip?.call();
          },
          child: const Text(
            'Skip Version',
            style: TextStyle(
              color: Color(0xFF666666),
              fontFamily: 'CascadiaCode',
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onLater?.call();
          },
          child: const Text(
            'Later',
            style: TextStyle(
              color: Color(0xFF999999),
              fontFamily: 'CascadiaCode',
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onUpdate?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text(
            'Update Now',
            style: TextStyle(
              fontFamily: 'CascadiaCode',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Show update dialog
  static Future<void> show(
    BuildContext context,
    UpdateInfo updateInfo, {
    VoidCallback? onSkip,
    VoidCallback? onLater,
    VoidCallback? onUpdate,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return UpdateDialog(
          updateInfo: updateInfo,
          onSkip: onSkip,
          onLater: onLater,
          onUpdate: onUpdate,
        );
      },
    );
  }
}
