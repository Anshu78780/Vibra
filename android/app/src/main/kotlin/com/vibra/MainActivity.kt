package com.vibra

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val BATTERY_OPTIMIZATION_CHANNEL = "com.vibra.audio/battery_optimization"
    private val BATTERY_OPTIMIZATION_FALLBACK_CHANNEL = "com.vibra.audio/battery_optimization_fallback"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_OPTIMIZATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val isIgnoring = isIgnoringBatteryOptimizations()
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    val requested = requestIgnoreBatteryOptimizations()
                    result.success(requested)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Fallback battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_OPTIMIZATION_FALLBACK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true // No battery optimization on older versions
        }
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                    true
                } else {
                    true // Already exempted
                }
            } else {
                true // No battery optimization on older versions
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
            // Fallback to app settings
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (fallbackException: Exception) {
                fallbackException.printStackTrace()
            }
        }
    }
}
