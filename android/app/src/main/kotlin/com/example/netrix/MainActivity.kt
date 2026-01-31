package com.example.netrix

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.util.Log

class MainActivity: FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if this is a silent widget refresh
        val isSilentMode = intent?.getBooleanExtra("silent_mode", false) ?: false
        val isWidgetRefresh = intent?.getBooleanExtra("widget_refresh", false) ?: false
        
        Log.d("MainActivity", "onCreate - silent_mode: $isSilentMode, widget_refresh: $isWidgetRefresh")
        
        if (isSilentMode && isWidgetRefresh) {
            Log.d("MainActivity", "Silent widget refresh - minimizing app")
            // Move app to background immediately
            moveTaskToBack(true)
        }
    }
    
    override fun onResume() {
        super.onResume()
        
        // Check again on resume in case onCreate was skipped
        val isSilentMode = intent?.getBooleanExtra("silent_mode", false) ?: false
        val isWidgetRefresh = intent?.getBooleanExtra("widget_refresh", false) ?: false
        
        if (isSilentMode && isWidgetRefresh) {
            Log.d("MainActivity", "Silent mode on resume - minimizing")
            moveTaskToBack(true)
        }
    }
}