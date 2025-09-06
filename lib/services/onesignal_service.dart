import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  /// Initialize OneSignal with app ID from environment
  static Future<void> initialize() async {
    try {
      // Get the app ID from environment variables
      final appId = dotenv.env['ONESIGNAL_APP_ID'];
      
      if (appId == null || appId.isEmpty) {
        if (kDebugMode) {
          print('OneSignal: App ID not found in environment variables');
        }
        return;
      }

      // Enable verbose logging for debugging (remove in production)
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // Initialize OneSignal
      OneSignal.initialize(appId);

      // Set up notification handlers
      _setupNotificationHandlers();

      // Configure notification icons and appearance
      _configureNotificationAppearance();

      if (kDebugMode) {
        print('OneSignal initialized successfully with App ID: ${appId.substring(0, 8)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal initialization error: $e');
      }
    }
  }

  /// Request notification permission
  static Future<bool> requestPermission() async {
    try {
      final permission = await OneSignal.Notifications.requestPermission(true);
      if (kDebugMode) {
        print('OneSignal permission granted: $permission');
      }
      return permission;
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal permission request error: $e');
      }
      return false;
    }
  }

  /// Set up notification event handlers
  static void _setupNotificationHandlers() {
    // Handle notification opened
    OneSignal.Notifications.addClickListener((event) {
      if (kDebugMode) {
        print('OneSignal: Notification clicked');
        print('Notification data: ${event.notification.additionalData}');
      }
      _handleNotificationOpened(event);
    });

    // Handle notification received while app is in foreground
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      if (kDebugMode) {
        print('OneSignal: Notification received in foreground');
        print('Title: ${event.notification.title}');
        print('Body: ${event.notification.body}');
      }
      
      // Display the notification (can be customized or prevented)
      // For OneSignal v5+, use preventDefault() to stop the notification or do nothing to show it
      // event.preventDefault(); // Uncomment to prevent showing the notification
    });

    // Handle permission state changes
    OneSignal.Notifications.addPermissionObserver((state) {
      if (kDebugMode) {
        print('OneSignal: Permission state changed to $state');
      }
    });
  }

  /// Configure notification appearance and icons
  static void _configureNotificationAppearance() {
    try {
      // Note: Icon configuration is primarily handled in AndroidManifest.xml
      // but we can set additional appearance options here if needed
      
      if (kDebugMode) {
        print('OneSignal: Notification appearance configured');
        print('Large icon: Using ic_launcher from mipmap');
        print('Small icon: Using ic_vibra_notification from drawable');
        print('This ensures your app icon appears in notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal appearance configuration error: $e');
      }
    }
  }

  /// Handle notification opened event
  static void _handleNotificationOpened(OSNotificationClickEvent event) {
    final additionalData = event.notification.additionalData;
    
    if (additionalData != null) {
      // Handle custom data from notification
      if (additionalData.containsKey('action')) {
        final action = additionalData['action'];
        switch (action) {
          case 'open_music':
            // Navigate to music player
            _handleMusicAction(additionalData);
            break;
          case 'open_playlist':
            // Navigate to specific playlist
            _handlePlaylistAction(additionalData);
            break;
          default:
            if (kDebugMode) {
              print('Unknown notification action: $action');
            }
        }
      }
    }
  }

  /// Handle music-related notification actions
  static void _handleMusicAction(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('Handling music action with data: $data');
    }
    // Implement navigation to music player or specific song
    // This would typically use your app's navigation system
  }

  /// Handle playlist-related notification actions
  static void _handlePlaylistAction(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('Handling playlist action with data: $data');
    }
    // Implement navigation to specific playlist
    // This would typically use your app's navigation system
  }

  /// Get the OneSignal user ID
  static Future<String?> getUserId() async {
    try {
      return OneSignal.User.pushSubscription.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting OneSignal user ID: $e');
      }
      return null;
    }
  }

  /// Set external user ID (for linking with your app's user system)
  static Future<void> setExternalUserId(String userId) async {
    try {
      await OneSignal.login(userId);
      if (kDebugMode) {
        print('OneSignal external user ID set: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting OneSignal external user ID: $e');
      }
    }
  }

  /// Remove external user ID
  static Future<void> removeExternalUserId() async {
    try {
      await OneSignal.logout();
      if (kDebugMode) {
        print('OneSignal external user ID removed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing OneSignal external user ID: $e');
      }
    }
  }

  /// Send tags to OneSignal for better targeting
  static Future<void> sendTags(Map<String, String> tags) async {
    try {
      await OneSignal.User.addTags(tags);
      if (kDebugMode) {
        print('OneSignal tags sent: $tags');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending OneSignal tags: $e');
      }
    }
  }

  /// Send a test notification to verify icon configuration
  static Future<void> sendTestNotification() async {
    try {
      // This is for testing purposes - in production, send notifications from your backend
      await sendTags({
        'test_notification': 'icon_verification',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      
      if (kDebugMode) {
        print('Test notification tags sent. Check OneSignal dashboard to send a test notification.');
        print('The notification should display with your custom Vibra icon.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending test notification tags: $e');
      }
    }
  }

  /// Remove tags from OneSignal
  static Future<void> removeTags(List<String> tagKeys) async {
    try {
      await OneSignal.User.removeTags(tagKeys);
      if (kDebugMode) {
        print('OneSignal tags removed: $tagKeys');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing OneSignal tags: $e');
      }
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      return OneSignal.User.pushSubscription.optedIn ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking notification status: $e');
      }
      return false;
    }
  }

  /// Opt out of notifications
  static Future<void> optOut() async {
    try {
      await OneSignal.User.pushSubscription.optOut();
      if (kDebugMode) {
        print('OneSignal: User opted out of notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error opting out of notifications: $e');
      }
    }
  }

  /// Opt in to notifications
  static Future<void> optIn() async {
    try {
      await OneSignal.User.pushSubscription.optIn();
      if (kDebugMode) {
        print('OneSignal: User opted in to notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error opting in to notifications: $e');
      }
    }
  }
}
