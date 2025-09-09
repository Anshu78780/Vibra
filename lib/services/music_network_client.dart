import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:uuid/uuid.dart';
import '../models/music_model.dart';
import 'simple_network_info.dart';

class MusicNetworkClient extends ChangeNotifier {
  static final MusicNetworkClient _instance = MusicNetworkClient._internal();
  factory MusicNetworkClient() => _instance;
  MusicNetworkClient._internal();

  final String _deviceId = const Uuid().v4();
  final List<RemoteDevice> _discoveredDevices = [];
  RemoteDevice? _connectedDevice;
  bool _isConnected = false;
  bool _isScanning = false;
  Timer? _heartbeatTimer;
  Timer? _statusUpdateTimer;
  MDnsClient? _mdnsClient;

  // Current remote status
  MusicTrack? _remoteCurrentTrack;
  bool _remoteIsPlaying = false;
  Duration _remotePosition = Duration.zero;
  Duration _remoteDuration = Duration.zero;
  List<MusicTrack> _remoteQueue = [];
  int _remoteCurrentIndex = -1;

  // Getters
  String get deviceId => _deviceId;
  List<RemoteDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  RemoteDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  MusicTrack? get remoteCurrentTrack => _remoteCurrentTrack;
  bool get remoteIsPlaying => _remoteIsPlaying;
  Duration get remotePosition => _remotePosition;
  Duration get remoteDuration => _remoteDuration;
  List<MusicTrack> get remoteQueue => List.unmodifiable(_remoteQueue);
  int get remoteCurrentIndex => _remoteCurrentIndex;

  Future<void> startScanning() async {
    if (_isScanning) return;
    
    try {
      _isScanning = true;
      _discoveredDevices.clear();
      notifyListeners();

      // Only try mDNS on non-Windows platforms
      if (!Platform.isWindows) {
        try {
          _mdnsClient = MDnsClient();
          await _mdnsClient!.start();
          print('📡 mDNS client started');
        } catch (e) {
          print('⚠️ mDNS failed, using direct network scan: $e');
        }
      } else {
        print('ℹ️ Windows detected - using direct network scan (mDNS not supported)');
      }

      // Scan for local HTTP servers on common ports
      await _scanLocalNetwork();
      
      print('🔍 Started scanning for music devices');
    } catch (e) {
      print('❌ Failed to start scanning: $e');
      _isScanning = false;
    }
    notifyListeners();
  }

  Future<void> stopScanning() async {
    try {
      _mdnsClient?.stop();
      _mdnsClient = null;
      _isScanning = false;
      print('🛑 Stopped scanning');
      notifyListeners();
    } catch (e) {
      print('❌ Error stopping scan: $e');
    }
  }

  Future<void> _scanLocalNetwork() async {
    // Get local IP address range
    try {
      // Scan common ports for music servers
      final baseIp = await _getLocalIpBase();
      if (baseIp == null) return;

      final futures = <Future>[];
      
      // Scan IPs in local network range
      for (int i = 1; i <= 254; i++) {
        final ip = '$baseIp.$i';
        // Expanded port range to match server's port trying logic
        for (int port in [8080, 8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8089]) {
          futures.add(_checkDevice(ip, port));
        }
      }

      await Future.wait(futures);
    } catch (e) {
      print('❌ Network scan error: $e');
    }
  }

  Future<String?> _getLocalIpBase() async {
    try {
      // Use our simple network detection
      final localIP = await SimpleNetworkInfo.getLocalIP();
      if (localIP != null) {
        return SimpleNetworkInfo.getBaseIP(localIP);
      }
    } catch (e) {
      print('❌ Failed to get local IP: $e');
    }
    return null;
  }

  Future<void> _checkDevice(String ip, int port) async {
    try {
      final response = await http.get(
        Uri.parse('http://$ip:$port/api/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final device = RemoteDevice(
          id: data['deviceId'] ?? '',
          name: data['deviceName'] ?? 'Unknown Device',
          ipAddress: ip,
          port: port,
          platform: data['platform'] ?? 'unknown',
          isPlaying: data['isPlaying'] ?? false,
          currentTrack: data['currentTrack'] != null 
              ? MusicTrack.fromJson(data['currentTrack'])
              : null,
        );

        // Avoid duplicates
        if (!_discoveredDevices.any((d) => d.id == device.id)) {
          _discoveredDevices.add(device);
          notifyListeners();
          print('📱 Found device: ${device.name} at $ip:$port');
        }
      }
    } catch (e) {
      // Ignore timeout and connection errors during scanning
    }
  }

  Future<bool> connectToDevice(RemoteDevice device) async {
    try {
      final response = await http.post(
        Uri.parse('http://${device.ipAddress}:${device.port}/api/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': _deviceId,
          'deviceName': Platform.isWindows ? 'Windows PC' : 'Android Device',
          'platform': Platform.operatingSystem,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _connectedDevice = device;
          _isConnected = true;
          
          // Start status updates
          _startStatusUpdates();
          _startHeartbeat();
          
          notifyListeners();
          print('✅ Connected to ${device.name}');
          return true;
        }
      }
    } catch (e) {
      print('❌ Failed to connect to ${device.name}: $e');
    }
    return false;
  }

  Future<void> disconnect() async {
    try {
      _heartbeatTimer?.cancel();
      _statusUpdateTimer?.cancel();
      _connectedDevice = null;
      _isConnected = false;
      _remoteCurrentTrack = null;
      _remoteIsPlaying = false;
      _remotePosition = Duration.zero;
      _remoteDuration = Duration.zero;
      _remoteQueue.clear();
      _remoteCurrentIndex = -1;
      
      notifyListeners();
      print('🔌 Disconnected from remote device');
    } catch (e) {
      print('❌ Error disconnecting: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_connectedDevice != null) {
        final isReachable = await _checkDeviceReachability();
        if (!isReachable) {
          await disconnect();
        }
      }
    });
  }

  void _startStatusUpdates() {
    _statusUpdateTimer?.cancel();
    int updateCount = 0;
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await updateRemoteStatus();
      // Update queue every 6th update (every 12 seconds) to avoid excessive requests
      updateCount++;
      if (updateCount % 6 == 0) {
        await updateRemoteQueue();
      }
    });
  }

  Future<bool> _checkDeviceReachability() async {
    if (_connectedDevice == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}/api/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateRemoteStatus() async {
    if (_connectedDevice == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}/api/status'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        _remoteIsPlaying = data['isPlaying'] ?? false;
        _remotePosition = Duration(milliseconds: data['position'] ?? 0);
        _remoteDuration = Duration(milliseconds: data['duration'] ?? 0);
        
        // Check if current track changed
        MusicTrack? newCurrentTrack;
        if (data['currentTrack'] != null) {
          newCurrentTrack = MusicTrack.fromJson(data['currentTrack']);
        }
        
        // If current track changed, refresh the queue
        if (_remoteCurrentTrack?.webpageUrl != newCurrentTrack?.webpageUrl) {
          _remoteCurrentTrack = newCurrentTrack;
          // Queue might have changed, update it
          await updateRemoteQueue();
        } else {
          _remoteCurrentTrack = newCurrentTrack;
        }
        
        notifyListeners();
      }
    } catch (e) {
      // Ignore errors during status updates
    }
  }

  // Remote control methods
  Future<bool> remotePlay() async {
    return await _sendCommand('/api/control/play');
  }

  Future<bool> remotePause() async {
    return await _sendCommand('/api/control/pause');
  }

  Future<bool> remoteNext() async {
    return await _sendCommand('/api/control/next');
  }

  Future<bool> remotePrevious() async {
    return await _sendCommand('/api/control/previous');
  }

  Future<bool> remoteSeek(Duration position) async {
    if (_connectedDevice == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}/api/control/seek'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'position': position.inMilliseconds}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('❌ Failed to seek: $e');
    }
    return false;
  }

  Future<bool> remotePlayFromQueue(int index) async {
    if (_connectedDevice == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}/api/control/play-from-queue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'index': index}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update current track info immediately
          await updateRemoteStatus();
          return true;
        }
      }
    } catch (e) {
      print('❌ Failed to play from queue: $e');
    }
    return false;
  }

  // New methods for enhanced control
  Future<bool> remotePlayTrack(MusicTrack track, {bool addToQueue = false}) async {
    if (_connectedDevice == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}/api/control/play-track'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'track': track.toJson(),
          'addToQueue': addToQueue,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update current track info immediately
          await updateRemoteStatus();
          return true;
        }
      }
    } catch (e) {
      print('❌ Failed to play track: $e');
    }
    return false;
  }

  Future<bool> remoteAddToQueue(dynamic tracksOrTrack) async {
    if (_connectedDevice == null) return false;
    
    try {
      Map<String, dynamic> body;
      
      if (tracksOrTrack is MusicTrack) {
        // Single track
        body = {'track': tracksOrTrack.toJson()};
      } else if (tracksOrTrack is List<MusicTrack>) {
        // Multiple tracks
        body = {'tracks': tracksOrTrack.map((track) => track.toJson()).toList()};
      } else {
        throw ArgumentError('tracksOrTrack must be either MusicTrack or List<MusicTrack>');
      }
      
      final response = await http.post(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}/api/control/add-to-queue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update queue info
          await updateRemoteQueue();
          return true;
        }
      }
    } catch (e) {
      print('❌ Failed to add to queue: $e');
    }
    return false;
  }

  Future<bool> remoteSetQueue(List<MusicTrack> tracks, {int startIndex = 0, bool autoPlay = true}) async {
    if (_connectedDevice == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}/api/control/set-queue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tracks': tracks.map((track) => track.toJson()).toList(),
          'startIndex': startIndex,
          'autoPlay': autoPlay,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update current track and queue info
          await updateRemoteStatus();
          await updateRemoteQueue();
          return true;
        }
      }
    } catch (e) {
      print('❌ Failed to set queue: $e');
    }
    return false;
  }

  Future<bool> remotePlayPlaylist(List<MusicTrack> tracks, {int startIndex = 0, bool replaceQueue = true}) async {
    if (_connectedDevice == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}/api/control/play-playlist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tracks': tracks.map((track) => track.toJson()).toList(),
          'startIndex': startIndex,
          'replaceQueue': replaceQueue,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update current track and queue info
          await updateRemoteStatus();
          await updateRemoteQueue();
          return true;
        }
      }
    } catch (e) {
      print('❌ Failed to play playlist: $e');
    }
    return false;
  }

  Future<void> updateRemoteQueue() async {
    if (_connectedDevice == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}/api/queue'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _remoteQueue = (data['queue'] as List)
              .map((track) => MusicTrack.fromJson(track))
              .toList();
          _remoteCurrentIndex = data['currentIndex'] ?? -1;
          
          // Update additional queue information if available
          if (data['currentTrack'] != null && data['isPlaying'] != null) {
            _remoteCurrentTrack = MusicTrack.fromJson(data['currentTrack']);
            _remoteIsPlaying = data['isPlaying'];
            _remotePosition = Duration(milliseconds: data['position'] ?? 0);
            _remoteDuration = Duration(milliseconds: data['duration'] ?? 0);
          }
          
          notifyListeners();
          print('📋 Updated remote queue: ${_remoteQueue.length} tracks, current index: $_remoteCurrentIndex');
        }
      }
    } catch (e) {
      print('❌ Failed to get queue: $e');
    }
  }

  Future<bool> _sendCommand(String endpoint) async {
    if (_connectedDevice == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse('http://${_connectedDevice!.ipAddress}:${_connectedDevice!.port}$endpoint'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('❌ Failed to send command $endpoint: $e');
    }
    return false;
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _statusUpdateTimer?.cancel();
    _mdnsClient?.stop();
    super.dispose();
  }
}

class RemoteDevice {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final String platform;
  final bool isPlaying;
  final MusicTrack? currentTrack;

  RemoteDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.platform,
    required this.isPlaying,
    this.currentTrack,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ipAddress': ipAddress,
    'port': port,
    'platform': platform,
    'isPlaying': isPlaying,
    'currentTrack': currentTrack?.toJson(),
  };
}
