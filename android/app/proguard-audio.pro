# Audio Service Pro-guard rules
-keep class com.ryanheise.audioservice.** { *; }
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

# Just Audio Pro-guard rules
-keep class com.ryanheise.just_audio.** { *; }

# Background audio handling
-keep class * extends android.media.browse.MediaBrowserService { *; }
-keep class * extends android.service.media.MediaBrowserService { *; }

# Keep notification classes
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class android.app.Notification** { *; }

# Keep media session classes
-keep class androidx.media.session.** { *; }
-keep class android.support.v4.media.session.** { *; }

# Keep wake lock classes
-keep class android.os.PowerManager** { *; }
-keep class android.os.PowerManager$WakeLock** { *; }
