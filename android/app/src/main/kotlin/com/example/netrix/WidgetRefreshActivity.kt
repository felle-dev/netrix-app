package com.example.netrix

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * Transparent activity that handles widget refresh silently
 * This activity has no UI and finishes immediately after triggering the refresh
 */
class WidgetRefreshActivity : Activity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "WidgetRefreshActivity started")
        
        // Set refresh flag
        val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
        prefs.edit().putBoolean("shouldRefresh", true).apply()
        
        // Send broadcast to trigger refresh if app is already running
        val broadcastIntent = Intent("com.example.netrix.WIDGET_REFRESH")
        sendBroadcast(broadcastIntent)
        
        // Trigger home_widget
        val triggerIntent = Intent("es.antonborri.home_widget.action.TRIGGER").apply {
            putExtra("url", "networkchecker://refresh")
        }
        sendBroadcast(triggerIntent)
        
        Log.d(TAG, "Broadcasts sent, finishing activity")
        
        // Finish immediately - no UI shown
        finish()
    }
    
    companion object {
        private const val TAG = "WidgetRefreshActivity"
    }
}