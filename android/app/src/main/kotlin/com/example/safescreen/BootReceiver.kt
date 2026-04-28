package com.example.safescreen

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("UsageLimits", Context.MODE_PRIVATE)
            val pkgsStr = prefs.getString("packages", "") ?: ""
            val limitsStr = prefs.getString("limits", "") ?: ""
            val globalLimit = prefs.getInt("globalLimit", 0)

            if (pkgsStr.isNotEmpty() && limitsStr.isNotEmpty()) {
                val packages = ArrayList(pkgsStr.split(","))
                val limits = ArrayList(limitsStr.split(",").mapNotNull { it.toIntOrNull() })

                val serviceIntent = Intent(context, UsageService::class.java).apply {
                    putStringArrayListExtra("PACKAGES", packages)
                    putIntegerArrayListExtra("LIMITS", limits)
                    putExtra("GLOBAL_LIMIT", globalLimit)
                }
                
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}
