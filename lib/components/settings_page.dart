import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            title: 'Playback',
            items: [
              _buildSettingsItem(
                icon: Icons.volume_up,
                title: 'Audio Quality',
                subtitle: 'High',
                onTap: () {},
              ),
              _buildSettingsItem(
                icon: Icons.repeat,
                title: 'Repeat Mode',
                subtitle: 'Off',
                onTap: () {},
              ),
              _buildSettingsItem(
                icon: Icons.shuffle,
                title: 'Shuffle',
                subtitle: 'Disabled',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'General',
            items: [
              _buildSettingsItem(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Enabled',
                onTap: () {},
              ),
              _buildSettingsItem(
                icon: Icons.download,
                title: 'Download Quality',
                subtitle: 'High',
                onTap: () {},
              ),
              _buildSettingsItem(
                icon: Icons.storage,
                title: 'Storage',
                subtitle: 'Manage downloads',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'About',
            items: [
              _buildSettingsItem(
                icon: Icons.info,
                title: 'Version',
                subtitle: '1.0.0',
                onTap: () {},
              ),
              _buildSettingsItem(
                icon: Icons.help,
                title: 'Help & Support',
                subtitle: 'Get help',
                onTap: () {},
              ),
              _buildSettingsItem(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                subtitle: 'Read our policy',
                onTap: () {},
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
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFF666666),
      ),
      onTap: onTap,
    );
  }
}
