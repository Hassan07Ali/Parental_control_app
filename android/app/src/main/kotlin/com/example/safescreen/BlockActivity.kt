package com.example.safescreen

import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView

class BlockActivity : ComponentActivity() {

    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.safescreen.ACTION_CLOSE_BLOCK_SCREEN") {
                finish()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Setup UI programmatically to avoid needing XML layouts
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0A0E1A")) // Dark background to match app theme
        }

        val icon = TextView(this).apply {
            text = "⏳"
            textSize = 64f
            gravity = Gravity.CENTER
        }

        val title = TextView(this).apply {
            text = "Time's Up!"
            textSize = 28f
            setTextColor(Color.parseColor("#00E5FF")) // Cyan color from app
            gravity = Gravity.CENTER
            setPadding(0, 20, 0, 10)
        }

        val subtitle = TextView(this).apply {
            text = "You've reached your screen time limit for this app."
            textSize = 16f
            setTextColor(Color.LTGRAY)
            gravity = Gravity.CENTER
            setPadding(40, 0, 40, 0)
        }

        layout.addView(icon)
        layout.addView(title)
        layout.addView(subtitle)

        setContentView(layout)

        // Register receiver to close this screen when service says so
        //  On Android 14+ (API 34), registerReceiver without an
        // export flag throws SecurityException. Use RECEIVER_NOT_EXPORTED
        // since this is an internal broadcast.
        val filter = IntentFilter("com.example.safescreen.ACTION_CLOSE_BLOCK_SCREEN")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(closeReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(closeReceiver, filter)
        }

        // Modern onBackPressed logic
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Prevent going back to the blocked app
                val homeIntent = Intent(Intent.ACTION_MAIN)
                homeIntent.addCategory(Intent.CATEGORY_HOME)
                homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(homeIntent)
            }
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(closeReceiver)
    }
}
