import 'package:flutter/material.dart';
import 'components/home_page.dart';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/onesignal_service.dart';
import 'utils/app_colors.dart';

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
