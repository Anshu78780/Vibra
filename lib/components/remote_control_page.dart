import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../services/music_network_server.dart';
import '../services/music_network_client.dart';
import '../services/windows_firewall_helper.dart';
import '../utils/app_colors.dart';
import '../controllers/music_player_controller.dart';
import 'mini_music_player.dart';
import 'remote_player_page.dart';
import 'qr_scanner_page.dart';

class RemoteControlPage extends StatefulWidget {
  const RemoteControlPage({super.key});

  @override
  State<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage>
    with TickerProviderStateMixin {
  final MusicNetworkServer _server = MusicNetworkServer();
  final MusicNetworkClient _client = MusicNetworkClient();
  final MusicPlayerController _playerController = MusicPlayerController();
  late TabController _tabController;
  bool _showQrCode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _server.addListener(_onServerStateChanged);
    _client.addListener(_onClientStateChanged);
    _playerController.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _server.removeListener(_onServerStateChanged);
    _client.removeListener(_onClientStateChanged);
    _playerController.removeListener(_onPlayerStateChanged);
    super.dispose();
  }

  void _onServerStateChanged() {
    if (mounted) setState(() {});
  }

  void _onClientStateChanged() {
    if (mounted) setState(() {});
  }

  void _onPlayerStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Music Ecosystem',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(
            fontFamily: 'CascadiaCode',
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(
              icon: Icon(Platform.isWindows ? Icons.computer : Icons.phone_android),
              text: 'Share Music',
            ),
            const Tab(
              icon: Icon(Icons.wifi_find),
              text: 'Connect',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServerTab(),
                _buildClientTab(),
              ],
            ),
          ),
          const MiniMusicPlayer(),
        ],
      ),
    );
  }

  Widget _buildServerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Server Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _server.isRunning 
                    ? AppColors.primary.withOpacity(0.3)
                    : AppColors.cardBackground,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _server.isRunning 
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _server.isRunning ? Icons.wifi_tethering : Icons.wifi_off,
                        color: _server.isRunning ? AppColors.primary : AppColors.textMuted,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _server.isRunning ? 'Music Server Active' : 'Music Server Inactive',
                            style: TextStyle(
                              color: _server.isRunning ? AppColors.primary : AppColors.textMuted,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'CascadiaCode',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _server.isRunning 
                                ? 'Other devices can connect to control music'
                                : 'Start server to allow remote control',
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
                if (_server.isRunning && _server.ipAddress != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBackground),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connection Details',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('IP Address', _server.ipAddress!),
                        _buildInfoRow('Port', _server.port.toString()),
                        _buildInfoRow('Device ID', _server.deviceId.substring(0, 8)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _server.isRunning ? _stopServer : _startServer,
                        icon: Icon(_server.isRunning ? Icons.stop : Icons.play_arrow),
                        label: Text(_server.isRunning ? 'Stop Server' : 'Start Server'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _server.isRunning ? AppColors.error : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'CascadiaCode',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (_server.isRunning && _server.ipAddress != null) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showQrCode = !_showQrCode;
                          });
                        },
                        icon: const Icon(Icons.qr_code),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        tooltip: 'Show QR Code',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // QR Code Card
          if (_showQrCode && _server.isRunning && _server.ipAddress != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Scan to Connect',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: 'vibra://${_server.ipAddress}:${_server.port}',
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'vibra://${_server.ipAddress}:${_server.port}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Connected Devices
          if (_server.isRunning) ...[
            const SizedBox(height: 20),
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
                  Row(
                    children: [
                      const Icon(
                        Icons.devices,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Connected Devices',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'CascadiaCode',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_server.connectedDevices.length}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_server.connectedDevices.isEmpty)
                    const Text(
                      'No devices connected',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontFamily: 'CascadiaCode',
                      ),
                    )
                  else
                    ...(_server.connectedDevices.map((device) => 
                        _buildConnectedDeviceItem(device))),
                ],
              ),
            ),
          ],

          // Current Track Info
          if (_playerController.hasTrack) ...[
            const SizedBox(height: 20),
            _buildCurrentTrackCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildClientTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scan Controls
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.secondary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _client.isScanning 
                    ? AppColors.secondary.withOpacity(0.3)
                    : AppColors.cardBackground,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _client.isScanning 
                            ? AppColors.secondary.withOpacity(0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _client.isScanning ? Icons.wifi_find : Icons.wifi_off,
                        color: _client.isScanning ? AppColors.secondary : AppColors.textMuted,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _client.isScanning ? 'Scanning for Devices' : 'Find Music Servers',
                            style: TextStyle(
                              color: _client.isScanning ? AppColors.secondary : AppColors.textMuted,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'CascadiaCode',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _client.isScanning 
                                ? 'Looking for devices on local network...'
                                : 'Scan to find devices running music servers',
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _client.isScanning ? _stopScanning : _startScanning,
                        icon: Icon(_client.isScanning ? Icons.stop : Icons.search),
                        label: Text(_client.isScanning ? 'Stop Scanning' : 'Scan for Devices'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _client.isScanning ? AppColors.error : AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'CascadiaCode',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!Platform.isWindows) // Hide QR scanner on Windows
                      ElevatedButton.icon(
                        onPressed: _scanQRCode,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'CascadiaCode',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Discovered Devices
          if (_client.discoveredDevices.isNotEmpty) ...[
            const SizedBox(height: 20),
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
                  Row(
                    children: [
                      const Icon(
                        Icons.devices_other,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Available Devices',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'CascadiaCode',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_client.discoveredDevices.length}',
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
                  const SizedBox(height: 12),
                  ...(_client.discoveredDevices.map((device) => 
                      _buildDiscoveredDeviceItem(device))),
                ],
              ),
            ),
          ],

          // Connected Device Remote Control
          if (_client.isConnected && _client.connectedDevice != null) ...[
            const SizedBox(height: 20),
            _buildConnectedDeviceCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontFamily: 'CascadiaCode',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontFamily: 'CascadiaCode',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceItem(ConnectedDevice device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            device.platform == 'windows' ? Icons.computer : Icons.phone_android,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                Text(
                  device.platform,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Connected',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredDeviceItem(RemoteDevice device) {
    final isConnected = _client.connectedDevice?.id == device.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConnected ? AppColors.primary.withOpacity(0.1) : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: isConnected ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Icon(
            device.platform == 'windows' ? Icons.computer : Icons.phone_android,
            color: isConnected ? AppColors.primary : AppColors.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                Text(
                  '${device.ipAddress}:${device.port}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                if (device.currentTrack != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '♪ ${device.currentTrack!.title}',
                    style: TextStyle(
                      color: AppColors.primary.withOpacity(0.8),
                      fontSize: 11,
                      fontFamily: 'CascadiaCode',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isConnected ? _disconnect : () => _connectToDevice(device),
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? AppColors.error : AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isConnected ? 'Disconnect' : 'Connect',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'CascadiaCode',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTrackCard() {
    final track = _playerController.currentTrack!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBackground),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.music_note,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Currently Playing',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  track.thumbnail,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    color: AppColors.cardBackground,
                    child: const Icon(Icons.music_note, color: AppColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'CascadiaCode',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'CascadiaCode',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _playerController.isPlaying ? Icons.play_circle : Icons.pause_circle,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _playerController.isPlaying ? 'Playing' : 'Paused',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontFamily: 'CascadiaCode',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceCard() {
    final device = _client.connectedDevice!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                device.platform == 'windows' ? Icons.computer : Icons.phone_android,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected to ${device.name}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                    Text(
                      device.ipAddress,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _disconnect,
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.2),
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RemotePlayerPage(
                          client: _client,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.music_note),
                  label: const Text('Open Player & Queue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Controls below',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteQueueCard() {
    final device = _client.connectedDevice!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                device.platform == 'windows' ? Icons.computer : Icons.phone_android,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected to ${device.name}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                    Text(
                      device.ipAddress,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _disconnect,
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.2),
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ),
          
          // Queue/Playlist Section
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.queue_music,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Queue',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'CascadiaCode',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_client.remoteQueue.length}',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          await _client.updateRemoteQueue();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.cardBackground,
                          foregroundColor: AppColors.textMuted,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_client.remoteQueue.isNotEmpty) ...[
                  Container(
                    height: 300, // Increased height since we removed the player controls
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _client.remoteQueue.length,
                      itemBuilder: (context, index) {
                        final track = _client.remoteQueue[index];
                        final isCurrentTrack = index == _client.remoteCurrentIndex;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrentTrack 
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: isCurrentTrack 
                                ? Border.all(color: AppColors.primary.withOpacity(0.3))
                                : null,
                          ),
                          child: Row(
                            children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    track.thumbnail,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 40,
                                      height: 40,
                                      color: AppColors.surface,
                                      child: const Icon(Icons.music_note, 
                                          color: AppColors.textMuted, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isCurrentTrack) ...[
                                            Icon(
                                              _client.remoteIsPlaying ? Icons.play_arrow : Icons.pause,
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
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        track.artist,
                                        style: TextStyle(
                                          color: isCurrentTrack 
                                              ? AppColors.primary.withOpacity(0.8)
                                              : AppColors.textSecondary,
                                          fontSize: 11,
                                          fontFamily: 'CascadiaCode',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isCurrentTrack 
                                        ? AppColors.primary 
                                        : AppColors.textMuted,
                                    fontSize: 12,
                                    fontFamily: 'CascadiaCode',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No tracks in queue\nMusic controls available in mini player below',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'CascadiaCode',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteControlCard() {
    final device = _client.connectedDevice!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                device.platform == 'windows' ? Icons.computer : Icons.phone_android,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected to ${device.name}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                    Text(
                      device.ipAddress,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _disconnect,
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.2),
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ),
          
          if (_client.remoteCurrentTrack != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _client.remoteCurrentTrack!.thumbnail,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 50,
                            height: 50,
                            color: AppColors.cardBackground,
                            child: const Icon(Icons.music_note, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _client.remoteCurrentTrack!.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'CascadiaCode',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _client.remoteCurrentTrack!.artist,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontFamily: 'CascadiaCode',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Progress Bar
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _client.remoteDuration.inMilliseconds > 0
                            ? _client.remotePosition.inMilliseconds / _client.remoteDuration.inMilliseconds
                            : 0.0,
                        backgroundColor: AppColors.cardBackground,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_client.remotePosition),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontFamily: 'CascadiaCode',
                            ),
                          ),
                          Text(
                            _formatDuration(_client.remoteDuration),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontFamily: 'CascadiaCode',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Control Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: _client.remotePrevious,
                        icon: const Icon(Icons.skip_previous),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      IconButton(
                        onPressed: _client.remoteIsPlaying ? _client.remotePause : _client.remotePlay,
                        icon: Icon(_client.remoteIsPlaying ? Icons.pause : Icons.play_arrow),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                      IconButton(
                        onPressed: _client.remoteNext,
                        icon: const Icon(Icons.skip_next),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Queue/Playlist Section
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.queue_music,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Queue',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_client.remoteQueue.length}',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'CascadiaCode',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () async {
                            await _client.updateRemoteQueue();
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.cardBackground,
                            foregroundColor: AppColors.textMuted,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_client.remoteQueue.isNotEmpty) ...[
                    Container(
                      height: 200,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _client.remoteQueue.length,
                        itemBuilder: (context, index) {
                          final track = _client.remoteQueue[index];
                          final isCurrentTrack = index == _client.remoteCurrentIndex;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrentTrack 
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: isCurrentTrack 
                                  ? Border.all(color: AppColors.primary.withOpacity(0.3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    track.thumbnail,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 40,
                                      height: 40,
                                      color: AppColors.surface,
                                      child: const Icon(Icons.music_note, 
                                          color: AppColors.textMuted, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isCurrentTrack) ...[
                                            Icon(
                                              _client.remoteIsPlaying ? Icons.play_arrow : Icons.pause,
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
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        track.artist,
                                        style: TextStyle(
                                          color: isCurrentTrack 
                                              ? AppColors.primary.withOpacity(0.8)
                                              : AppColors.textSecondary,
                                          fontSize: 11,
                                          fontFamily: 'CascadiaCode',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isCurrentTrack 
                                        ? AppColors.primary 
                                        : AppColors.textMuted,
                                    fontSize: 12,
                                    fontFamily: 'CascadiaCode',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No tracks in queue',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontFamily: 'CascadiaCode',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No music playing on remote device',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _startServer() async {
    final success = await _server.startServer();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Music server started! Other devices can now connect.',
            style: TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } else if (mounted) {
      // Show detailed error message with firewall instructions
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Server Start Failed',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'CascadiaCode',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Could not start the music server. This might be due to:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'CascadiaCode',
                ),
              ),
              const SizedBox(height: 16),
              if (Platform.isWindows) ...[
                const Text(
                  '• Windows Firewall blocking network access',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Ports 8080-8089 being used by other apps',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'To fix: Go to Windows Security → Firewall & network protection → Allow an app through firewall → Add Vibra to the list',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _buildFirewallHelpDialog(),
                    );
                  },
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Detailed Instructions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'CascadiaCode',
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  '• Network permissions not granted',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Not connected to WiFi network',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'CascadiaCode',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: AppColors.primary,
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _stopServer() async {
    await _server.stopServer();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Music server stopped.',
            style: TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  Future<void> _startScanning() async {
    await _client.startScanning();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Scanning for music devices...',
            style: TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  Future<void> _stopScanning() async {
    await _client.stopScanning();
  }

  Future<void> _connectToDevice(RemoteDevice device) async {
    final success = await _client.connectToDevice(device);
    if (success && mounted) {
      await _client.updateRemoteQueue();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connected to ${device.name}',
            style: const TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to connect to ${device.name}',
            style: const TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _client.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Disconnected from remote device',
            style: TextStyle(fontFamily: 'CascadiaCode'),
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  Future<void> _scanQRCode() async {
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerPage(),
        ),
      );

      if (result != null && result['host'] != null && result['port'] != null) {
        final device = RemoteDevice(
          id: 'qr-scanned',
          name: 'Scanned Device',
          ipAddress: result['host'],
          port: result['port'],
          platform: 'unknown',
          isPlaying: false,
        );

        await _connectToDevice(device);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to scan QR code: $e',
              style: const TextStyle(fontFamily: 'CascadiaCode'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildFirewallHelpDialog() {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Windows Firewall Setup',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontFamily: 'CascadiaCode',
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Text(
            WindowsFirewallHelper.getFirewallInstructions(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'CascadiaCode',
              fontSize: 13,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(
              color: AppColors.primary,
              fontFamily: 'CascadiaCode',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (Platform.isWindows)
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await WindowsFirewallHelper.addFirewallRule();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                        ? 'Firewall rule added! You may need to restart the app.'
                        : 'Failed to add firewall rule. Please add manually or run as administrator.',
                      style: const TextStyle(fontFamily: 'CascadiaCode'),
                    ),
                    backgroundColor: success ? AppColors.primary : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Auto Fix (Admin Required)',
              style: TextStyle(fontFamily: 'CascadiaCode'),
            ),
          ),
      ],
    );
  }
}
