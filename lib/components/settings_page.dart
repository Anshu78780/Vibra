import 'package:flutter/material.dart';
import 'downloads_page.dart';
import 'update_dialog.dart';
import '../services/update_manager.dart';

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
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      backgroundColor: const Color(0xFFB91C1C),
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
                style: TextStyle(fontFamily: 'monospace'),
              ),
              backgroundColor: Color(0xFF4CAF50),
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
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
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
                          color: Color(0xFFB91C1C),
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
              color: Color(0xFF999999),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
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
    return ListTile(
      leading: Icon(
        icon,
        color: const Color(0xFF666666),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'monospace',
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF999999),
          fontSize: 14,
          fontFamily: 'monospace',
        ),
      ),
      trailing: trailing ?? const Icon(
        Icons.chevron_right,
        color: Color(0xFF666666),
      ),
      onTap: onTap,
    );
  }
}
