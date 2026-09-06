package com.highai.high_ai

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts a small app-level (not ai_engine-scoped) channel for device
 * capability checks — e.g. total RAM — used before offering a multi-GB
 * model download, per the app's error-handling requirements around
 * insufficient RAM/unsupported devices. This is deliberately separate
 * from the ai_engine plugin's channels: it is about the device, not the
 * inference engine.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "high_ai/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getMemoryInfo") {
                    val activityManager =
                        getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val memoryInfo = ActivityManager.MemoryInfo()
                    activityManager.getMemoryInfo(memoryInfo)
                    result.success(
                        mapOf(
                            "totalRamBytes" to memoryInfo.totalMem,
                            "availableRamBytes" to memoryInfo.availMem,
                        ),
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
