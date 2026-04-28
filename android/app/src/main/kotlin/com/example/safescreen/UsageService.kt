package com.example.safescreen

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.util.Calendar

class UsageService : Service() {

    private val monitoredApps = mutableMapOf<String, Long>()   // pkg → limit in ms
    private var globalLimitInMillis: Long = 0
    private var isWarningScreenVisible = false

    private val handler = Handler(Looper.getMainLooper())
    private val checkInterval: Long = 2000

    private val checkUsageRunnable = object : Runnable {
        override fun run() {
            try { checkUsageAndEnforce() } catch (e: Exception) { e.printStackTrace() }
            handler.postDelayed(this, checkInterval)
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForegroundServiceNotification()
    }

    private fun startForegroundServiceNotification() {
        val channelId = "SmartScreen_Monitor"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "App Monitoring", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification = androidx.core.app.NotificationCompat.Builder(this, channelId)
            .setContentTitle("Monitoring Active")
            .setContentText("Enforcing limits.")
            .setSmallIcon(android.R.drawable.ic_secure)
            .setOngoing(true)
            .build()
        startForeground(1, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packages = intent?.getStringArrayListExtra("PACKAGES")
        val limits   = intent?.getIntegerArrayListExtra("LIMITS")
        globalLimitInMillis = (intent?.getIntExtra("GLOBAL_LIMIT", 0) ?: 0) * 60 * 1000L

        monitoredApps.clear()
        if (packages != null && limits != null) {
            for (i in packages.indices) {
                monitoredApps[packages[i]] = limits[i] * 60 * 1000L
            }
            handler.removeCallbacks(checkUsageRunnable)
            handler.post(checkUsageRunnable)
        }
        return START_STICKY
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main enforcement loop — runs every 2 seconds
    // ─────────────────────────────────────────────────────────────────────────
    private fun checkUsageAndEnforce() {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val activePackage = getForegroundApp(usm) ?: return

        val isSystemApp = activePackage.contains("launcher")
                || activePackage == packageName
                || activePackage.startsWith("com.android.systemui")

        // 1. Enforce GLOBAL limit
        if (globalLimitInMillis > 0) {
            val totalMs = getTotalDailyUsageMs(usm)          // FIX: event-based
            if (totalMs >= globalLimitInMillis && !isSystemApp) {
                if (!isWarningScreenVisible) {
                    showWarningOverlay()
                    isWarningScreenVisible = true
                }
                return
            }
        } else if (globalLimitInMillis == 0L && isWarningScreenVisible) {
            removeWarningOverlay()
            isWarningScreenVisible = false
        }

        // 2. Enforce INDIVIDUAL app limits
        if (monitoredApps.containsKey(activePackage)) {
            val limitMs = monitoredApps[activePackage]!!
            // FIX: Use event-based calcUsageMs instead of queryUsageStats.
            // queryUsageStats with INTERVAL_BEST on MIUI returns stale
            // aggregated buckets that do not respect the startTime you pass,
            // so the app usage appears higher than it really is and the
            // popup fires before the limit is actually reached.
            val appUsedMs = calcUsageMs(usm, activePackage, todayMidnightMs(), System.currentTimeMillis())

            if (appUsedMs >= limitMs) {
                if (!isWarningScreenVisible) {
                    showWarningOverlay()
                    isWarningScreenVisible = true
                }
            } else {
                if (isWarningScreenVisible) {
                    removeWarningOverlay()
                    isWarningScreenVisible = false
                }
            }
        } else {
            if (isWarningScreenVisible) {
                removeWarningOverlay()
                isWarningScreenVisible = false
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FIX: Replaced old queryUsageStats version with event-based calculation.
    // Same logic as MainActivity.calcUsageMs — sums only the ms that fall
    // inside [todayMidnight, now] so MIUI cannot bleed previous-day data in.
    // ─────────────────────────────────────────────────────────────────────────
    private fun getTotalDailyUsageMs(usm: UsageStatsManager): Long =
        calcUsageMs(usm, null, todayMidnightMs(), System.currentTimeMillis())

    // ─────────────────────────────────────────────────────────────────────────
    // Event-based usage calculator — shared with getTotalDailyUsageMs
    // and the individual-app check above.
    //
    // targetPkg == null  → sum ALL non-system packages (device total)
    // targetPkg != null  → sum only that package
    //
    // Clamps every session to [startMs, endMs] so time that happened before
    // midnight is never counted even if the resume event was before midnight.
    // ─────────────────────────────────────────────────────────────────────────
    private fun calcUsageMs(
        usm: UsageStatsManager,
        targetPkg: String?,
        startMs: Long,
        endMs: Long
    ): Long {
        val events = usm.queryEvents(startMs, endMs) ?: return 0L
        val event = UsageEvents.Event()
        val resumedAt = mutableMapOf<String, Long>()
        var totalMs = 0L

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
                    val sessionStart = maxOf(resumeTime, startMs)
                    val sessionEnd   = minOf(event.timeStamp, endMs)
                    if (sessionEnd > sessionStart) totalMs += sessionEnd - sessionStart
                }
            }
        }

        // App still in foreground — no PAUSED event yet, count up to now
        for ((pkg, resumeTime) in resumedAt) {
            if (targetPkg != null && pkg != targetPkg) continue
            val sessionStart = maxOf(resumeTime, startMs)
            val sessionEnd   = minOf(endMs, System.currentTimeMillis())
            if (sessionEnd > sessionStart) totalMs += sessionEnd - sessionStart
        }

        return totalMs
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Gets the package name of the app currently in foreground by reading
    // the last ACTIVITY_RESUMED event from the past hour.
    // ─────────────────────────────────────────────────────────────────────────
    private fun getForegroundApp(usm: UsageStatsManager): String? {
        val endTime    = System.currentTimeMillis()
        val usageEvents = usm.queryEvents(endTime - (1000 * 60 * 60), endTime)
        val event = UsageEvents.Event()
        var latestPackage: String? = null
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                latestPackage = event.packageName
            }
        }
        return latestPackage
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun todayMidnightMs(): Long =
        Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun isSystemPackage(pkg: String): Boolean =
        pkg.startsWith("com.android.")
            || pkg.startsWith("android")
            || pkg.startsWith("com.miui.")
            || pkg == packageName

    private fun showWarningOverlay() {
        startActivity(Intent(this, BlockActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
        })
    }

    private fun removeWarningOverlay() {
        sendBroadcast(Intent("com.example.safescreen.ACTION_CLOSE_BLOCK_SCREEN"))
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(checkUsageRunnable)
        removeWarningOverlay()
    }
}