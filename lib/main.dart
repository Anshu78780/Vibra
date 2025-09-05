import 'package:flutter/material.dart';
import 'components/home_page.dart';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Request notifications on Android 13+ so media notification can show
  if (Platform.isAndroid) {
    try {
      await Permission.notification.request();
    } catch (_) {}
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibra',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'monospace', color: Colors.white),
          displayMedium: TextStyle(fontFamily: 'monospace', color: Colors.white),
          displaySmall: TextStyle(fontFamily: 'monospace', color: Colors.white),
          headlineLarge: TextStyle(fontFamily: 'monospace', color: Colors.white),
          headlineMedium: TextStyle(fontFamily: 'monospace', color: Colors.white),
          headlineSmall: TextStyle(fontFamily: 'monospace', color: Colors.white),
          titleLarge: TextStyle(fontFamily: 'monospace', color: Colors.white),
          titleMedium: TextStyle(fontFamily: 'monospace', color: Colors.white),
          titleSmall: TextStyle(fontFamily: 'monospace', color: Colors.white),
          bodyLarge: TextStyle(fontFamily: 'monospace', color: Colors.white),
          bodyMedium: TextStyle(fontFamily: 'monospace', color: Colors.white),
          bodySmall: TextStyle(fontFamily: 'monospace', color: Colors.white),
          labelLarge: TextStyle(fontFamily: 'monospace', color: Colors.white),
          labelMedium: TextStyle(fontFamily: 'monospace', color: Colors.white),
          labelSmall: TextStyle(fontFamily: 'monospace', color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontFamily: 'monospace',
            color: Colors.white,
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
