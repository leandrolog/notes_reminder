package com.example.notes_reminder_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "notes_reminder/exact_alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openExactAlarmSettings" -> {
                        openExactAlarmSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Opens the system "Alarms & reminders" screen. Many OEM ROMs do not
    // implement ACTION_REQUEST_SCHEDULE_EXACT_ALARM, so on failure we fall back
    // to the app's details page, which always exists and lets the user reach
    // the special-permissions section manually.
    private fun openExactAlarmSettings() {
        val packageUri = Uri.parse("package:$packageName")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                startActivity(
                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, packageUri)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                return
            } catch (_: Exception) {
                // Fall through to the app details page below.
            }
        }

        try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (_: Exception) {
            // Nothing else we can reasonably do; leave the user on the app.
        }
    }
}
