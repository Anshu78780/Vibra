import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

/// Utility class for handling storage permissions
class StoragePermissionHelper {
  
  /// Request storage permissions for Android with user-friendly dialogs
  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    
    try {
      // Check if permission is already granted
      if (await Permission.manageExternalStorage.isGranted || 
          await Permission.storage.isGranted) {
        return true;
      }
      
      // Show explanation dialog first
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            'Storage Permission Required',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'CascadiaCode',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Vibra needs storage permission to save music files to your Downloads/Vibra/ folder. '
            'This allows you to listen to music offline and manage your downloads.',
            style: TextStyle(
              color: Color(0xFF999999),
              fontFamily: 'CascadiaCode',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Not Now',
                style: TextStyle(
                  color: Color(0xFF999999),
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Grant Permission',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontFamily: 'CascadiaCode',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      
      if (shouldRequest != true) return false;
      
      // Try to request MANAGE_EXTERNAL_STORAGE for Android 11+
      var status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        return true;
      }
      
      // Fallback to regular storage permission
      status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }
      
      // If permission denied, show settings dialog
      if (status.isPermanentlyDenied) {
        return await _showSettingsDialog(context);
      }
      
      return false;
    } catch (e) {
      print('❌ Error requesting storage permission: $e');
      return false;
    }
  }
  
  /// Show dialog to redirect user to app settings
  static Future<bool> _showSettingsDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Permission Required',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'CascadiaCode',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Storage permission was denied. Please enable it in Settings > Apps > Vibra > Permissions > Storage to download music.',
          style: TextStyle(
            color: Color(0xFF999999),
            fontFamily: 'CascadiaCode',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF999999),
                fontFamily: 'CascadiaCode',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, true);
              await openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontFamily: 'CascadiaCode',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }
  
  /// Check current permission status
  static Future<PermissionStatus> getStoragePermissionStatus() async {
    if (!Platform.isAndroid) return PermissionStatus.granted;
    
    try {
      // Check MANAGE_EXTERNAL_STORAGE first (Android 11+)
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return manageStatus;
      
      // Fallback to regular storage permission
      return await Permission.storage.status;
    } catch (e) {
      print('❌ Error checking storage permission: $e');
      return PermissionStatus.denied;
    }
  }
  
  /// Show download location info dialog
  static void showDownloadLocationInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Download Location',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'CascadiaCode',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (Platform.isAndroid) ...[
              const Text(
                'Your music downloads are saved to:',
                style: TextStyle(
                  color: Color(0xFF999999),
                  fontFamily: 'CascadiaCode',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '/storage/emulated/0/Download/Vibra/',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontFamily: 'CascadiaCode',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can access these files through your file manager or share them with other apps.',
                style: TextStyle(
                  color: Color(0xFF999999),
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ] else ...[
              const Text(
                'Downloads are saved in the app\'s private storage and can be accessed through the Downloads tab.',
                style: TextStyle(
                  color: Color(0xFF999999),
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
              'Got it',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontFamily: 'CascadiaCode',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
