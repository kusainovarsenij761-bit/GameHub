package com.example.gamehub

import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "gamehub/game_mode"
    private var previousFilter: Int? = null
    private var changedFilterByUs = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDndSettings" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("DND_SETTINGS", e.message, null)
                        }
                    }
                    "launchGame" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("BAD_PACKAGE", "Не указан пакет игры", null)
                            return@setMethodCallHandler
                        }
                        try {
                            enableDndIfAllowed()
                            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                            if (launchIntent == null) {
                                result.success("not_found")
                            } else {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success("launched")
                            }
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun enableDndIfAllowed() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (!nm.isNotificationPolicyAccessGranted) return
        if (previousFilter == null) {
            previousFilter = nm.currentInterruptionFilter
        }
        try {
            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            changedFilterByUs = true
        } catch (_: SecurityException) {
            // Access can be revoked in system settings; game launch should still proceed.
        }
    }

    override fun onResume() {
        super.onResume()
        // Restores the previous DND filter when the user returns to GameHub.
        // Android cannot guarantee restoration if the app process is killed or user stays on home screen.
        if (changedFilterByUs && previousFilter != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                try {
                    nm.setInterruptionFilter(previousFilter!!)
                } catch (_: SecurityException) {
                }
            }
            previousFilter = null
            changedFilterByUs = false
        }
    }
}
