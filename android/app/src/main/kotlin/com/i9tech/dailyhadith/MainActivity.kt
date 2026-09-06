package com.i9tech.dailyhadith

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Host side of the two reminder controls `flutter_local_notifications` does
 * not reach.
 *
 * Battery optimisation is the usual reason a reminder that was scheduled
 * correctly never arrives: Android — and, far more aggressively, several
 * manufacturer skins — put an app it considers idle to sleep and drop its
 * pending alarms with it. The exemption has its own system dialog, and the
 * reader decides.
 *
 * The other is the way back into notification settings, for once the OS has
 * stopped offering its own permission prompt.
 *
 * Everything here is best-effort: a device that cannot open one of these
 * screens reports "no" and the app carries on.
 */
class MainActivity : FlutterActivity() {

    /** The Dart call waiting on the battery-optimisation dialog, if any. */
    private var pendingExemption: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isIgnoringBatteryOptimizations" -> result.success(isExemptFromBatteryOptimisation())
            "requestIgnoreBatteryOptimizations" -> requestBatteryOptimisationExemption(result)
            "openNotificationSettings" -> result.success(openNotificationSettings())
            else -> result.notImplemented()
        }
    }

    private fun isExemptFromBatteryOptimisation(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestBatteryOptimisationExemption(result: MethodChannel.Result) {
        if (isExemptFromBatteryOptimisation()) {
            result.success(true)
            return
        }

        // A second request supersedes the first; answer the old caller with the
        // current state rather than leaving its future hanging.
        settlePendingExemption()

        val request = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:$packageName"))
        try {
            pendingExemption = result
            startActivityForResult(request, EXEMPTION_REQUEST_CODE)
        } catch (error: ActivityNotFoundException) {
            pendingExemption = null
            // Some builds ship without the direct dialog. The full list screen
            // is the next best thing; the reader finds the app on it themselves,
            // and the app re-reads the real state when it comes back to the
            // foreground.
            openBatteryOptimisationSettings()
            result.success(false)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != EXEMPTION_REQUEST_CODE) return
        // The result code is not worth reading — the dialog reports cancelled
        // even when the reader allowed it. Ask the OS what actually changed.
        settlePendingExemption()
    }

    override fun onDestroy() {
        // Never leave the Dart side awaiting a reply that can no longer arrive.
        settlePendingExemption()
        super.onDestroy()
    }

    private fun settlePendingExemption() {
        val waiting = pendingExemption ?: return
        pendingExemption = null
        runCatching { waiting.success(isExemptFromBatteryOptimisation()) }
    }

    private fun openBatteryOptimisationSettings(): Boolean =
        startFirstAvailable(listOf(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)))

    /**
     * Opens this app's notification settings, falling back to its app info
     * page on versions that have no dedicated screen.
     */
    private fun openNotificationSettings(): Boolean {
        val candidates = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            candidates += Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
        candidates += Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.parse("package:$packageName"))
        return startFirstAvailable(candidates)
    }

    private fun startFirstAvailable(intents: List<Intent>): Boolean {
        for (intent in intents) {
            try {
                startActivity(intent)
                return true
            } catch (error: ActivityNotFoundException) {
                // Try the next one.
            }
        }
        return false
    }

    private companion object {
        const val CHANNEL = "com.i9tech.dailyhadith/power"

        /**
         * Distinct from the codes `flutter_local_notifications` uses for its own
         * permission screens, which arrive at the same activity.
         */
        const val EXEMPTION_REQUEST_CODE = 3489
    }
}
