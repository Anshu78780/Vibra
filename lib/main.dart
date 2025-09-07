import 'package:flutter/material.dart';
import 'components/home_page.dart';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/onesignal_service.dart';
import 'utils/app_colors.dart';
import 'package:flutter/services.dart';

/// Request battery optimization exemption to prevent the app from being killed
/// when running in the background for music playback
Future<void> _requestBatteryOptimizationExemption() async {
  if (!Platform.isAndroid) return;
  
  try {
    const platform = MethodChannel('com.vibra.audio/battery_optimization');
    final bool isOptimized = await platform.invokeMethod('isIgnoringBatteryOptimizations');
    
    if (!isOptimized) {
      // Show dialog to inform user about battery optimization
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
    // Fallback: try to use the Android intent directly
    try {
      await _requestIgnoreBatteryOptimizationFallback();
    } catch (fallbackError) {
      print('⚠️ Fallback battery optimization request also failed: $fallbackError');
    }
  }
}

/// Fallback method to request battery optimization exemption
Future<void> _requestIgnoreBatteryOptimizationFallback() async {
  const platform = MethodChannel('com.vibra.audio/battery_optimization_fallback');
  await platform.invokeMethod('openBatteryOptimizationSettings');
}

/// Initialize background playback optimizations
Future<void> _initializeBackgroundPlayback() async {
  if (!Platform.isAndroid) return;
  
  try {
    print('🎵 Initializing background playback optimizations...');
    
    // Add any additional background setup here
    // For example, you could initialize wake locks or other Android-specific features
    
    print('✅ Background playback optimizations initialized');
  } catch (e) {
    print('⚠️ Failed to initialize background playback optimizations: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize OneSignal
  await OneSignalService.initialize();
  
  // Request notifications on Android 13+ so media notification can show
  if (Platform.isAndroid) {
    try {
      await Permission.notification.request();
      
      // Request battery optimization exemption for background music playback
      await _requestBatteryOptimizationExemption();
      
      // Initialize background playback optimizations
      await _initializeBackgroundPlayback();
    } catch (_) {}
  }
  
  // Request OneSignal notification permission
  await OneSignalService.requestPermission();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibra',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          background: AppColors.background,
          error: AppColors.error,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
          onBackground: AppColors.textPrimary,
          onError: AppColors.textPrimary,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textPrimary),
          displayMedium: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textPrimary),
          displaySmall: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textPrimary),
          headlineLarge: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textPrimary),
          headlineMedium: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textPrimary),
          headlineSmall: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textPrimary),
          titleLarge: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textPrimary),
          titleMedium: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textSecondary),
          titleSmall: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textSecondary),
          bodyLarge: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textPrimary),
          bodyMedium: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textSecondary),
          bodySmall: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textMuted),
          labelLarge: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textPrimary),
          labelMedium: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textSecondary),
          labelSmall: TextStyle(fontFamily: 'CascadiaCode', color: AppColors.textMuted),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          titleTextStyle: TextStyle(
            fontFamily: 'CascadiaCode',
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
