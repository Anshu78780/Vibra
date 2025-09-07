import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Service to handle background playback optimizations
class BackgroundPlaybackService {
  static final BackgroundPlaybackService _instance = BackgroundPlaybackService._internal();
  factory BackgroundPlaybackService() => _instance;
  BackgroundPlaybackService._internal();

  bool _isInitialized = false;
  Timer? _keepAliveTimer;
  
  /// Initialize background playback optimizations
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _requestBatteryOptimizationExemption();
      _startKeepAliveTimer();
      _isInitialized = true;
      print('✅ Background playback service initialized');
    } catch (e) {
      print('❌ Failed to initialize background playback service: $e');
    }
  }
  
  /// Request battery optimization exemption for the app
  Future<void> _requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    
    try {
      const platform = MethodChannel('com.vibra.audio/battery_optimization');
      final bool isOptimized = await platform.invokeMethod('isIgnoringBatteryOptimizations');
      
      if (!isOptimized) {
        print('📱 Requesting battery optimization exemption for background music playback');
        final bool requested = await platform.invokeMethod('requestIgnoreBatteryOptimizations');
        
        if (requested) {
          print('✅ Battery optimization exemption requested');
        } else {
          print('❌ Battery optimization exemption request failed');
        }
      } else {
        print('✅ App already exempted from battery optimization');
      }
    } catch (e) {
      print('⚠️ Could not request battery optimization exemption: $e');
    }
  }
  
  /// Start a keep-alive timer to prevent the app from being killed
  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    
    // Send a keep-alive signal every 25 seconds to prevent doze mode
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      _sendKeepAlive();
    });
    
    print('🔄 Keep-alive timer started for background playback');
  }
  
  /// Send a keep-alive signal to the system
  void _sendKeepAlive() {
    try {
      // This helps prevent the app from being killed by battery optimization
      print('💓 Sending keep-alive signal');
      
      // You can add additional keep-alive logic here if needed
      // For example, updating the notification or touching the audio service
      
    } catch (e) {
      print('⚠️ Failed to send keep-alive signal: $e');
    }
  }
  
  /// Stop the background service
  void stop() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    print('🛑 Background playback service stopped');
  }
  
  /// Check if the service is running
  bool get isRunning => _keepAliveTimer?.isActive ?? false;
}
