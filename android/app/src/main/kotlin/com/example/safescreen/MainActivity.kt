package com.example.safescreen

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Process
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.safescreen/usage_control"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "configureUsageLimit" -> {
                        if (!Settings.canDrawOverlays(this)) {
                            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")))
                            result.error("PERMISSION_DENIED",
                                "Please grant Overlay Permission and try again.", null)
                            return@setMethodCallHandler
                        }
                        if (!hasUsageStatsPermission()) {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.error("PERMISSION_DENIED",
                                "Please grant Usage Access Permission and try again.", null)
                            return@setMethodCallHandler
                        }
                        // Ask MIUI to stop killing our service
                        try {
                            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                startActivity(Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")))
                            }
                        } catch (e: Exception) { e.printStackTrace() }

                        val appLimits   = call.argument<Map<String, Int>>("appLimits")
                        val globalLimit = call.argument<Int>("globalLimit") ?: 0

                        if (appLimits != null && appLimits.isNotEmpty()) {
                            val serviceIntent = Intent(this, UsageService::class.java).apply {
                                putStringArrayListExtra("PACKAGES", ArrayList(appLimits.keys))
                                putIntegerArrayListExtra("LIMITS",   ArrayList(appLimits.values))
                                putExtra("GLOBAL_LIMIT", globalLimit)
                            }
                            startService(serviceIntent)
                            result.success("Service Started")
                        } else {
                            stopService(Intent(this, UsageService::class.java))
                            result.success("Service Stopped")
                        }
                    }

                    "getDeviceTotalUsage" -> {
                        val usm     = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                        val totalMs = calcUsageMs(usm, null, todayMidnightMs(), System.currentTimeMillis())
                        result.success((totalMs / (1000 * 60)).toInt())
                    }

                    "getBatchRemainingTime" -> {
                        val appLimits = call.argument<Map<String, Int>>("appLimits")
                        if (appLimits == null) {
                            result.error("INVALID_ARGUMENT", "appLimits cannot be null", null)
                            return@setMethodCallHandler
                        }
                        val usm        = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                        val midnightMs = todayMidnightMs()
                        val nowMs      = System.currentTimeMillis()

                        val remaining = mutableMapOf<String, Int>()
                        for ((pkg, limit) in appLimits) {
                            val usedMs  = calcUsageMs(usm, pkg, midnightMs, nowMs)
                            val usedMin = (usedMs / (1000 * 60)).toInt()
                            remaining[pkg] = maxOf(0, limit - usedMin)
                        }
                        result.success(remaining)
                    }

                    "getWeeklyUsage" -> {
                        val usm        = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                        val nowMs      = System.currentTimeMillis()
                        val weeklyData = mutableMapOf<String, Any>()

                        for (daysAgo in 6 downTo 0) {
                            val dayStart = Calendar.getInstance().apply {
                                add(Calendar.DAY_OF_YEAR, -daysAgo)
                                set(Calendar.HOUR_OF_DAY, 0)
                                set(Calendar.MINUTE, 0)
                                set(Calendar.SECOND, 0)
                                set(Calendar.MILLISECOND, 0)
                            }
                            // For today cap at now — prevents future bleed.
                            // For past days cap at 23:59:59.999 of that day.
                            val dayEndMs = if (daysAgo == 0) {
                                nowMs
                            } else {
                                Calendar.getInstance().apply {
                                    add(Calendar.DAY_OF_YEAR, -daysAgo)
                                    set(Calendar.HOUR_OF_DAY, 23)
                                    set(Calendar.MINUTE, 59)
                                    set(Calendar.SECOND, 59)
                                    set(Calendar.MILLISECOND, 999)
                                }.timeInMillis
                            }

                            // queryEvents — accurate per-ms, no MIUI bucket bleed
                            val totalMs = calcUsageMs(usm, null,
                                dayStart.timeInMillis, dayEndMs)

                            val dateKey = "${dayStart.get(Calendar.YEAR)}-" +
                                String.format("%02d", dayStart.get(Calendar.MONTH) + 1) + "-" +
                                String.format("%02d", dayStart.get(Calendar.DAY_OF_MONTH))
                            weeklyData[dateKey] = (totalMs / (1000 * 60)).toInt()
                        }
                        result.success(weeklyData)
                    }

                    "getCategorizedUsage" -> {
                        val usm    = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                        val perPkg = calcAllPackagesUsageMs(usm,
                            todayMidnightMs(), System.currentTimeMillis())

                        val list = mutableListOf<Map<String, Any>>()
                        for ((pkg, ms) in perPkg) {
                            val minutes = (ms / (1000 * 60)).toInt()
                            if (minutes > 0) {
                                list.add(mapOf("packageName" to pkg, "minutes" to minutes))
                            }
                        }
                        result.success(list)
                    }

                    "getTopAppsUsage" -> {
                        val usm    = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                        val perPkg = calcAllPackagesUsageMs(usm,
                            todayMidnightMs(), System.currentTimeMillis())
                        val pm     = packageManager
                        val list   = mutableListOf<Map<String, Any>>()

                        for ((pkg, ms) in perPkg) {
                            val mins = (ms / (1000 * 60)).toInt()
                            if (mins > 0) {
                                try {
                                    val name = pm.getApplicationLabel(
                                        pm.getApplicationInfo(pkg, 0)).toString()
                                    list.add(mapOf(
                                        "packageName" to pkg,
                                        "appName"     to name,
                                        "minutes"     to mins))
                                } catch (_: Exception) {}
                            }
                        }
                        result.success(
                            list.sortedByDescending { it["minutes"] as Int }.take(10))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /** Epoch-ms for 00:00:00.000 today in the device's local timezone. */
    private fun todayMidnightMs(): Long =
        Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    /**
     * Calculates foreground usage in ms for [targetPkg] (or all non-system
     * packages when null) by walking raw OS events between [startMs] and [endMs].
     *
     * Uses queryEvents instead of queryUsageStats to avoid MIUI's bucket-bleed
     * bug where pre-aggregated daily buckets carry yesterday's data into today.
     */
    private fun calcUsageMs(
        usm: UsageStatsManager,
        targetPkg: String?,
        startMs: Long,
        endMs: Long
    ): Long {
        val events    = usm.queryEvents(startMs, endMs) ?: return 0L
        val event     = UsageEvents.Event()
        val resumedAt = mutableMapOf<String, Long>()
        var totalMs   = 0L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (isSystemPackage(pkg)) continue
            if (targetPkg != null && pkg != targetPkg) continue

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    resumedAt[pkg] = event.timeStamp
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    val resumeTime = resumedAt.remove(pkg) ?: continue
                    val s = maxOf(resumeTime, startMs)
                    val e = minOf(event.timeStamp, endMs)
                    if (e > s) totalMs += e - s
                }
            }
        }

        // App still in foreground — count up to endMs
        for ((pkg, resumeTime) in resumedAt) {
            if (targetPkg != null && pkg != targetPkg) continue
            val s = maxOf(resumeTime, startMs)
            val e = minOf(endMs, System.currentTimeMillis())
            if (e > s) totalMs += e - s
        }

        return totalMs
    }

    /**
     * Same event-log logic but returns a packageName → ms map for all
     * non-system packages in a single pass (efficient for category breakdown).
     */
    private fun calcAllPackagesUsageMs(
        usm: UsageStatsManager,
        startMs: Long,
        endMs: Long
    ): Map<String, Long> {
        val events    = usm.queryEvents(startMs, endMs) ?: return emptyMap()
        val event     = UsageEvents.Event()
        val resumedAt = mutableMapOf<String, Long>()
        val totals    = mutableMapOf<String, Long>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (isSystemPackage(pkg)) continue

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> resumedAt[pkg] = event.timeStamp
                UsageEvents.Event.ACTIVITY_PAUSED  -> {
                    val resumeTime = resumedAt.remove(pkg) ?: continue
                    val s = maxOf(resumeTime, startMs)
                    val e = minOf(event.timeStamp, endMs)
                    if (e > s) totals[pkg] = (totals[pkg] ?: 0L) + (e - s)
                }
            }
        }

        val nowMs = System.currentTimeMillis()
        for ((pkg, resumeTime) in resumedAt) {
            val s = maxOf(resumeTime, startMs)
            val e = minOf(endMs, nowMs)
            if (e > s) totals[pkg] = (totals[pkg] ?: 0L) + (e - s)
        }

        return totals
    }

    private fun isSystemPackage(pkg: String): Boolean =
        pkg.startsWith("com.android.")
            || pkg.startsWith("android")
            || pkg.startsWith("com.miui.")
            || pkg == packageName

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(), packageName
        ) == AppOpsManager.MODE_ALLOWED
    }
}