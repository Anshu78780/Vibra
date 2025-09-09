import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:uuid/uuid.dart';
import '../controllers/music_player_controller.dart';
import '../models/music_model.dart';
import 'simple_network_info.dart';

class MusicNetworkServer extends ChangeNotifier {
  static final MusicNetworkServer _instance = MusicNetworkServer._internal();
  factory MusicNetworkServer() => _instance;
  MusicNetworkServer._internal();

  HttpServer? _server;
  MDnsClient? _mdnsClient;
  final String _deviceId = const Uuid().v4();
  final String _serviceName = 'vibra-music';
  final String _serviceType = '_vibra._tcp';
  int _port = 8080;
  bool _isRunning = false;
  String? _ipAddress;
  final List<ConnectedDevice> _connectedDevices = [];
  final MusicPlayerController _playerController = MusicPlayerController();

  // Getters
  bool get isRunning => _isRunning;
  String? get ipAddress => _ipAddress;
  int get port => _port;
  String get deviceId => _deviceId;
  List<ConnectedDevice> get connectedDevices => List.unmodifiable(_connectedDevices);

  Future<bool> startServer() async {
    try {
      if (_isRunning) return true;

      // Get local IP address using simple network detection
      _ipAddress = await SimpleNetworkInfo.getLocalIP();
      
      if (_ipAddress == null) {
        print('❌ Could not get IP address');
        return false;
      }

      // Try multiple ports to find an available one
      final portsToTry = [8080, 8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8089];
      HttpServer? server;
      
      for (final port in portsToTry) {
        try {
          // Try to bind to the port
          server = await HttpServer.bind(_ipAddress!, port);
          _port = port;
          print('🎵 Successfully bound to $_ipAddress:$port');
          break;
        } catch (e) {
          print('⚠️ Port $port unavailable: $e');
          if (port == portsToTry.last) {
            print('❌ No available ports found');
            return false;
          }
        }
      }
      
      if (server == null) {
        print('❌ Could not bind to any port');
        return false;
      }
      
      _server = server;
      _isRunning = true;
      
      print('🎵 Music server started on $_ipAddress:$_port');
      
      // Start mDNS service
      await _startMdnsService();
      
      // Listen for connections
      _server!.listen(_handleRequest);
      
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Failed to start server: $e');
      return false;
    }
  }

  Future<void> stopServer() async {
    try {
      await _server?.close();
      _mdnsClient?.stop();
      _server = null;
      _mdnsClient = null;
      _isRunning = false;
      _connectedDevices.clear();
      print('🛑 Music server stopped');
      notifyListeners();
    } catch (e) {
      print('❌ Error stopping server: $e');
    }
  }

  Future<void> _startMdnsService() async {
    // Skip mDNS on Windows due to permission and socket limitations
    if (Platform.isWindows) {
      print('ℹ️ Skipping mDNS on Windows (not supported due to socket limitations)');
      return;
    }
    
    try {
      _mdnsClient = MDnsClient();
      await _mdnsClient!.start();
      
      print('📡 mDNS service started');
    } catch (e) {
      print('❌ Failed to start mDNS: $e');
      // Don't fail the entire server if mDNS fails
      print('ℹ️ Continuing without mDNS - devices can still connect via IP address');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    
    // Enable CORS
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (request.method == 'OPTIONS') {
      response.statusCode = 200;
      await response.close();
      return;
    }

    try {
      final path = request.uri.path;
      final method = request.method;
      
      switch (path) {
        case '/api/status':
          await _handleStatus(request, response);
          break;
        case '/api/connect':
          await _handleConnect(request, response);
          break;
        case '/api/control/play':
          await _handlePlay(request, response);
          break;
        case '/api/control/pause':
          await _handlePause(request, response);
          break;
        case '/api/control/next':
          await _handleNext(request, response);
          break;
        case '/api/control/previous':
          await _handlePrevious(request, response);
          break;
        case '/api/control/seek':
          await _handleSeek(request, response);
          break;
        case '/api/control/play-from-queue':
          await _handlePlayFromQueue(request, response);
          break;
        case '/api/current-track':
          await _handleCurrentTrack(request, response);
          break;
        case '/api/queue':
          await _handleQueue(request, response);
          break;
        case '/api/control/play-track':
          await _handlePlayTrack(request, response);
          break;
        case '/api/control/add-to-queue':
          await _handleAddToQueue(request, response);
          break;
        case '/api/control/set-queue':
          await _handleSetQueue(request, response);
          break;
        case '/api/control/play-playlist':
          await _handlePlayPlaylist(request, response);
          break;
        case '/api/test':
          response.write(jsonEncode({'success': true, 'message': 'Test endpoint works'}));
          break;
        default:
          response.statusCode = 404;
          response.write(jsonEncode({
            'error': 'Endpoint not found', 
            'path': path,
            'method': method
          }));
      }
    } catch (e) {
      response.statusCode = 500;
      response.write(jsonEncode({'error': e.toString()}));
    }
    
    await response.close();
  }

  Future<void> _handleStatus(HttpRequest request, HttpResponse response) async {
    final status = {
      'deviceId': _deviceId,
      'deviceName': Platform.isWindows ? 'Windows PC' : 'Android Device',
      'isPlaying': _playerController.isPlaying,
      'currentTrack': _playerController.currentTrack?.toJson(),
      'position': _playerController.position.inMilliseconds,
      'duration': _playerController.duration.inMilliseconds,
      'volume': 1.0, // TODO: Add volume control
      'queueLength': _playerController.queue.length,
      'platform': Platform.operatingSystem,
    };
    
    response.write(jsonEncode(status));
  }

  Future<void> _handleConnect(HttpRequest request, HttpResponse response) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body);
    
    // Get client IP address
    final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    
    final device = ConnectedDevice(
      id: data['deviceId'] ?? const Uuid().v4(),
      name: data['deviceName'] ?? 'Unknown Device',
      platform: data['platform'] ?? 'unknown',
      ipAddress: clientIp,
      connectedAt: DateTime.now(),
    );
    
    _connectedDevices.add(device);
    notifyListeners();
    
    response.write(jsonEncode({
      'success': true,
      'message': 'Connected successfully',
      'serverId': _deviceId,
    }));
  }

  Future<void> _handlePlay(HttpRequest request, HttpResponse response) async {
    await _playerController.resume();
    response.write(jsonEncode({'success': true, 'action': 'play'}));
  }

  Future<void> _handlePause(HttpRequest request, HttpResponse response) async {
    await _playerController.pause();
    response.write(jsonEncode({'success': true, 'action': 'pause'}));
  }

  Future<void> _handleNext(HttpRequest request, HttpResponse response) async {
    await _playerController.playNext();
    response.write(jsonEncode({'success': true, 'action': 'next'}));
  }

  Future<void> _handlePrevious(HttpRequest request, HttpResponse response) async {
    await _playerController.playPrevious();
    response.write(jsonEncode({'success': true, 'action': 'previous'}));
  }

  Future<void> _handleSeek(HttpRequest request, HttpResponse response) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body);
    final positionMs = data['position'] as int;
    
    await _playerController.seek(Duration(milliseconds: positionMs));
    response.write(jsonEncode({'success': true, 'action': 'seek', 'position': positionMs}));
  }

  Future<void> _handlePlayFromQueue(HttpRequest request, HttpResponse response) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body);
    final index = data['index'] as int;
    
    if (index >= 0 && index < _playerController.queue.length) {
      await _playerController.playTrackFromQueue(_playerController.queue, index);
      response.write(jsonEncode({
        'success': true, 
        'action': 'play_from_queue', 
        'index': index,
        'track': _playerController.currentTrack?.toJson()
      }));
    } else {
      response.write(jsonEncode({
        'success': false,
        'message': 'Invalid queue index: $index',
      }));
    }
  }

  Future<void> _handleCurrentTrack(HttpRequest request, HttpResponse response) async {
    final track = _playerController.currentTrack;
    if (track != null) {
      response.write(jsonEncode({
        'success': true,
        'track': track.toJson(),
        'position': _playerController.position.inMilliseconds,
        'duration': _playerController.duration.inMilliseconds,
        'isPlaying': _playerController.isPlaying,
      }));
    } else {
      response.write(jsonEncode({
        'success': false,
        'message': 'No track currently playing',
      }));
    }
  }

  Future<void> _handleQueue(HttpRequest request, HttpResponse response) async {
    final queue = _playerController.queue.map((track) => track.toJson()).toList();
    final queueInfo = {
      'success': true,
      'queue': queue,
      'currentIndex': _playerController.currentIndex,
      'queueLength': _playerController.queue.length,
      'hasNext': _playerController.hasNext,
      'hasPrevious': _playerController.hasPrevious,
      'currentTrack': _playerController.currentTrack?.toJson(),
      'isPlaying': _playerController.isPlaying,
      'position': _playerController.position.inMilliseconds,
      'duration': _playerController.duration.inMilliseconds,
    };
    response.write(jsonEncode(queueInfo));
  }

  Future<void> _handlePlayTrack(HttpRequest request, HttpResponse response) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body);
      
      if (data['track'] == null) {
        response.write(jsonEncode({
          'success': false,
          'message': 'Track data is required',
        }));
        return;
      }
      
      final track = MusicTrack.fromJson(data['track']);
      final addToQueue = data['addToQueue'] ?? false;
      
      if (addToQueue) {
        // Add to queue and optionally play
        _playerController.addToQueue(track);
        if (_playerController.currentTrack == null) {
          // If nothing is playing, start playing this track
          await _playerController.playTrackFromQueue(_playerController.queue, _playerController.queue.length - 1);
        }
      } else {
        // Play immediately with recommendations
        await _playerController.playTrackWithRecommendations(track);
      }
      
      response.write(jsonEncode({
        'success': true,
        'action': 'play_track',
        'track': track.toJson(),
        'addedToQueue': addToQueue,
        'currentTrack': _playerController.currentTrack?.toJson(),
      }));
    } catch (e) {
      response.write(jsonEncode({
        'success': false,
        'message': 'Failed to play track: $e',
      }));
    }
  }

  Future<void> _handleAddToQueue(HttpRequest request, HttpResponse response) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body);
      
      if (data['track'] != null) {
        // Single track
        final track = MusicTrack.fromJson(data['track']);
        _playerController.addToQueue(track);
        
        response.write(jsonEncode({
          'success': true,
          'action': 'add_to_queue',
          'track': track.toJson(),
          'queueLength': _playerController.queue.length,
        }));
      } else if (data['tracks'] != null) {
        // Multiple tracks
        final tracks = (data['tracks'] as List)
            .map((trackJson) => MusicTrack.fromJson(trackJson))
            .toList();
        
        for (final track in tracks) {
          _playerController.addToQueue(track);
        }
        
        response.write(jsonEncode({
          'success': true,
          'action': 'add_multiple_to_queue',
          'tracksAdded': tracks.length,
          'queueLength': _playerController.queue.length,
        }));
      } else {
        response.write(jsonEncode({
          'success': false,
          'message': 'Track or tracks data is required',
        }));
      }
    } catch (e) {
      response.write(jsonEncode({
        'success': false,
        'message': 'Failed to add to queue: $e',
      }));
    }
  }

  Future<void> _handleSetQueue(HttpRequest request, HttpResponse response) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body);
      
      if (data['tracks'] == null) {
        response.write(jsonEncode({
          'success': false,
          'message': 'Tracks data is required',
        }));
        return;
      }
      
      final tracks = (data['tracks'] as List)
          .map((trackJson) => MusicTrack.fromJson(trackJson))
          .toList();
      
      final startIndex = data['startIndex'] ?? 0;
      final autoPlay = data['autoPlay'] ?? true;
      
      // Set the new queue
      _playerController.setQueue(tracks);
      
      // Optionally start playing from the specified index
      if (autoPlay && tracks.isNotEmpty && startIndex >= 0 && startIndex < tracks.length) {
        await _playerController.playTrackFromQueue(tracks, startIndex);
      }
      
      response.write(jsonEncode({
        'success': true,
        'action': 'set_queue',
        'queueLength': tracks.length,
        'startIndex': startIndex,
        'autoPlay': autoPlay,
        'currentTrack': _playerController.currentTrack?.toJson(),
      }));
    } catch (e) {
      response.write(jsonEncode({
        'success': false,
        'message': 'Failed to set queue: $e',
      }));
    }
  }

  Future<void> _handlePlayPlaylist(HttpRequest request, HttpResponse response) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body);
      
      if (data['tracks'] == null) {
        response.write(jsonEncode({
          'success': false,
          'message': 'Tracks data is required',
        }));
        return;
      }
      
      final tracks = (data['tracks'] as List)
          .map((trackJson) => MusicTrack.fromJson(trackJson))
          .toList();
      
      final startIndex = data['startIndex'] ?? 0;
      final replaceQueue = data['replaceQueue'] ?? true;
      
      if (replaceQueue) {
        // Replace the current queue with the playlist
        _playerController.setQueue(tracks);
      } else {
        // Add playlist to the existing queue
        for (final track in tracks) {
          _playerController.addToQueue(track);
        }
      }
      
      // Start playing from the specified index
      if (tracks.isNotEmpty && startIndex >= 0 && startIndex < tracks.length) {
        final playIndex = replaceQueue ? startIndex : (_playerController.queue.length - tracks.length + startIndex);
        await _playerController.playTrackFromQueue(_playerController.queue, playIndex);
      }
      
      response.write(jsonEncode({
        'success': true,
        'action': 'play_playlist',
        'tracksAdded': tracks.length,
        'startIndex': startIndex,
        'replaceQueue': replaceQueue,
        'queueLength': _playerController.queue.length,
        'currentTrack': _playerController.currentTrack?.toJson(),
      }));
    } catch (e) {
      response.write(jsonEncode({
        'success': false,
        'message': 'Failed to play playlist: $e',
      }));
    }
  }
}

class ConnectedDevice {
  final String id;
  final String name;
  final String platform;
  final String ipAddress;
  final DateTime connectedAt;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.ipAddress,
    required this.connectedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'platform': platform,
    'ipAddress': ipAddress,
    'connectedAt': connectedAt.toIso8601String(),
  };
}
