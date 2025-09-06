import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'downloads_page.dart';

import 'update_dialog.dart';
import '../services/update_manager.dart';
import '../utils/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isCheckingForUpdates = false;

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingForUpdates = true;
    });

    try {
      final updateInfo = await UpdateManager.checkForUpdates();
      
      if (mounted) {
        setState(() {
          _isCheckingForUpdates = false;
        });

        if (updateInfo != null) {
          // Show update dialog
          await UpdateDialog.show(
            context,
            updateInfo,
            onSkip: () async {
              await UpdateManager.skipVersion(updateInfo.latestVersion);
            },
            onLater: () {
              // Do nothing
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
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            },
          );
        } else {
          // No update available
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You have the latest version!',
                style: TextStyle(fontFamily: 'CascadiaCode'),
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingForUpdates = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to check for updates: $e',
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Only show Downloads on non-Windows platforms
          if (!Platform.isWindows)
            _buildSettingsSection(
              title: 'General',
              items: [
                _buildSettingsItem(
                  icon: Icons.storage,
                  title: 'Downloads',
                  subtitle: 'Manage downloads',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DownloadsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          if (!Platform.isWindows) const SizedBox(height: 16),
          
          // Notifications section - display only for now
          _buildSettingsSection(
            title: 'Notifications',
            items: [
              _buildSettingsItem(
                icon: Icons.notifications,
                title: 'Push Notifications',
                subtitle: 'Coming soon - notification preferences',
                onTap: () {
                  // Show coming soon message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notification settings coming soon!',
                        style: TextStyle(fontFamily: 'CascadiaCode'),
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Soon',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSettingsSection(
            title: 'App',
            items: [
              _buildSettingsItem(
                icon: Icons.system_update,
                title: 'Check for Updates',
                subtitle: _isCheckingForUpdates 
                    ? 'Checking...' 
                    : 'Check for new app versions',
                onTap: _isCheckingForUpdates ? () {} : _checkForUpdates,
                trailing: _isCheckingForUpdates 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'CascadiaCode',
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.cardBackground,
              width: 1,
            ),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBackground,
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.background,
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'CascadiaCode',
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontFamily: 'CascadiaCode',
          ),
        ),
        trailing: trailing ?? const Icon(
          Icons.chevron_right,
          color: AppColors.textMuted,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
