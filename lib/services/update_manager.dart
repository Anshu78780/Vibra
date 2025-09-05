import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateManager {
  static const String _githubApiUrl = 'https://api.github.com/repos/Anshu78780/vibra/releases/latest';
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _skipVersionKey = 'skip_version';
  
  /// Check for updates from GitHub releases
  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Make API request to GitHub
      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Vibra-Music-App',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        print('GitHub API error: ${response.statusCode}');
        return null;
      }
      
      final releaseData = json.decode(response.body);
      final latestVersion = releaseData['tag_name']?.toString().replaceFirst('v', '') ?? '';
      
      if (latestVersion.isEmpty) {
        return null;
      }
      
      // Compare versions
      if (_isNewerVersion(currentVersion, latestVersion)) {
        // Check if user has skipped this version
        final prefs = await SharedPreferences.getInstance();
        final skippedVersion = prefs.getString(_skipVersionKey);
        
        if (skippedVersion == latestVersion) {
          return null; // User has skipped this version
        }
        
        // Find appropriate APK for device architecture
        final downloadUrl = _getDownloadUrl(releaseData['assets']);
        
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          releaseNotes: releaseData['body']?.toString() ?? 'New update available',
          downloadUrl: downloadUrl,
          releaseUrl: releaseData['html_url']?.toString() ?? '',
          publishedAt: releaseData['published_at']?.toString() ?? '',
        );
      }
      
      // Update last check time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUpdateCheckKey, DateTime.now().millisecondsSinceEpoch);
      
      return null; // No update available
    } catch (e) {
      print('Error checking for updates: $e');
      return null;
    }
  }
  
  /// Get appropriate download URL based on device architecture
  static String _getDownloadUrl(List<dynamic> assets) {
    // Default to arm64-v8a (most common for modern Android devices)
    String fallbackUrl = '';
    String arm64Url = '';
    String armv7Url = '';
    String x86Url = '';
    
    for (final asset in assets) {
      final name = asset['name']?.toString().toLowerCase() ?? '';
      final downloadUrl = asset['browser_download_url']?.toString() ?? '';
      
      if (name.contains('.apk')) {
        if (fallbackUrl.isEmpty) fallbackUrl = downloadUrl;
        
        if (name.contains('arm64-v8a')) {
          arm64Url = downloadUrl;
        } else if (name.contains('armeabi-v7a')) {
          armv7Url = downloadUrl;
        } else if (name.contains('x86_64')) {
          x86Url = downloadUrl;
        }
      }
    }
    
    // Return arm64 as default, then armv7, then x86, then any APK
    return arm64Url.isNotEmpty 
        ? arm64Url 
        : (armv7Url.isNotEmpty 
            ? armv7Url 
            : (x86Url.isNotEmpty ? x86Url : fallbackUrl));
  }
  
  /// Compare version strings (semantic versioning)
  static bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();
      
      // Ensure both have same number of parts
      while (currentParts.length < 3) currentParts.add(0);
      while (latestParts.length < 3) latestParts.add(0);
      
      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      
      return false; // Versions are equal
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }
  
  /// Check if enough time has passed since last update check
  static Future<bool> shouldCheckForUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastUpdateCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check once per day (24 hours)
      const checkInterval = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
      
      return (now - lastCheck) > checkInterval;
    } catch (e) {
      return true; // Default to checking if there's an error
    }
  }
  
  /// Skip this version (user doesn't want to update)
  static Future<void> skipVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skipVersionKey, version);
    } catch (e) {
      print('Error skipping version: $e');
    }
  }
  
  /// Clear skipped version (when user wants to see updates again)
  static Future<void> clearSkippedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_skipVersionKey);
    } catch (e) {
      print('Error clearing skipped version: $e');
    }
  }
  
  /// Open download URL in browser
  static Future<void> downloadUpdate(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error launching download URL: $e');
      rethrow;
    }
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String releaseUrl;
  final String publishedAt;
  
  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.publishedAt,
  });
  
  @override
  String toString() {
    return 'UpdateInfo(current: $currentVersion, latest: $latestVersion)';
  }
}
