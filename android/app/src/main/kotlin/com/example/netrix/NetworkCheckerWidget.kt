package com.example.netrix

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.os.Build
import android.view.View
import android.util.Log
import java.text.SimpleDateFormat
import java.util.*

class NetworkCheckerWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        Log.d(TAG, "onReceive: ${intent.action}")
        
        when (intent.action) {
            ACTION_REFRESH -> {
                Log.d(TAG, "Refresh button clicked!")
                
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, NetworkCheckerWidget::class.java)
                )
                
                for (appWidgetId in appWidgetIds) {
                    showLoadingState(context, appWidgetManager, appWidgetId, 0, "Triggered", "Refresh at ${getCurrentTime()}")
                }
                
                // Set refresh flag
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putBoolean("shouldRefresh", true).apply()
                Log.d(TAG, "Set shouldRefresh flag")
                
                // Open app in background (won't show UI if using MainActivity properly)
                try {
                    val appIntent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_MAIN
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                                Intent.FLAG_ACTIVITY_NO_ANIMATION or
                                Intent.FLAG_FROM_BACKGROUND
                        putExtra("widget_refresh", true)
                        putExtra("silent_mode", true)
                    }
                    context.startActivity(appIntent)
                    Log.d(TAG, "Started MainActivity in background")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start activity: $e")
                }
            }
        }
    }

    companion object {
        private const val TAG = "NetworkCheckerWidget"
        private const val ACTION_REFRESH = "com.example.netrix.REFRESH"
        private const val PREFS_NAME = "HomeWidgetPreferences"

        private fun getCurrentTime(): String {
            val format = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
            return format.format(Date())
        }

        private fun showLoadingState(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            percentage: Int = 0,
            status: String = "Loading...",
            debug: String = "Waiting for app"
        ) {
            Log.d(TAG, "showLoadingState: $percentage% - $status - $debug")
            
            val isDarkMode = isDarkMode(context)
            val views = RemoteViews(context.packageName, R.layout.network_checker_widget)
            
            views.setViewVisibility(R.id.error_layout, View.GONE)
            views.setViewVisibility(R.id.main_content, View.GONE)
            views.setViewVisibility(R.id.ip_section, View.GONE)
            views.setViewVisibility(R.id.tor_banner, View.GONE)
            views.setViewVisibility(R.id.header_layout, View.VISIBLE)
            views.setViewVisibility(R.id.loading_layout, View.VISIBLE)
            
            views.setTextViewText(R.id.loading_text, status)
            views.setTextViewText(R.id.loading_percentage, "$percentage%")
            views.setTextViewText(R.id.loading_debug, "Debug: $debug")
            views.setTextViewText(R.id.loading_timestamp, "Started: ${getCurrentTime()}")
            
            applyTheme(views, isDarkMode)
            setupRefreshButton(context, views)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            val isLoading = prefs.getBoolean("isLoading", false)
            
            if (isLoading) {
                val percentage = prefs.getInt("loadingPercentage", 0)
                val status = prefs.getString("loadingStatus", "Loading...") ?: "Loading..."
                val debug = prefs.getString("loadingDebug", "Processing...") ?: "Processing..."
                
                Log.d(TAG, "updateAppWidget in loading state: $percentage%")
                showLoadingState(context, appWidgetManager, appWidgetId, percentage, status, debug)
                return
            }
            
            val hasError = prefs.getBoolean("hasError", false)
            val country = prefs.getString("country", "Unknown") ?: "Unknown"
            val city = prefs.getString("city", "") ?: ""
            val publicIP = prefs.getString("publicIP", "•••.•••.•••.•••") ?: "•••.•••.•••.•••"
            val flag = prefs.getString("flag", "🌍") ?: "🌍"
            val isTor = prefs.getBoolean("isTor", false)
            val lastUpdate = prefs.getString("lastUpdate", null)
            val errorMessage = prefs.getString("errorMessage", "Unable to load")
            
            Log.d(TAG, "updateAppWidget: country=$country, hasError=$hasError")
            
            val isDarkMode = isDarkMode(context)
            val views = RemoteViews(context.packageName, R.layout.network_checker_widget)

            views.setViewVisibility(R.id.loading_layout, View.GONE)

            if (hasError) {
                views.setViewVisibility(R.id.error_layout, View.VISIBLE)
                views.setViewVisibility(R.id.header_layout, View.GONE)
                views.setViewVisibility(R.id.main_content, View.GONE)
                views.setViewVisibility(R.id.ip_section, View.GONE)
                views.setViewVisibility(R.id.tor_banner, View.GONE)
                views.setTextViewText(R.id.error_message, errorMessage)
            } else {
                views.setViewVisibility(R.id.error_layout, View.GONE)
                views.setViewVisibility(R.id.header_layout, View.VISIBLE)
                views.setViewVisibility(R.id.main_content, View.VISIBLE)
                views.setViewVisibility(R.id.ip_section, View.VISIBLE)

                val headerText = if (isTor) "Your Tor Exit Location" else "Your Location"
                views.setTextViewText(R.id.header_text, headerText)

                views.setTextViewText(R.id.country_flag, flag)
                views.setTextViewText(R.id.country_name, country)
                
                if (city.isNotEmpty() && city != "Unknown") {
                    views.setViewVisibility(R.id.city_name, View.VISIBLE)
                    views.setTextViewText(R.id.city_name, city)
                } else {
                    views.setViewVisibility(R.id.city_name, View.GONE)
                }

                val maskedIP = maskIP(publicIP)
                views.setTextViewText(R.id.ip_address, maskedIP)

                if (isTor) {
                    views.setViewVisibility(R.id.tor_banner, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.tor_banner, View.GONE)
                }

                if (lastUpdate != null) {
                    val updateText = formatLastUpdate(lastUpdate)
                    views.setTextViewText(R.id.last_update, updateText)
                }
            }

            applyTheme(views, isDarkMode)
            setupRefreshButton(context, views)

            // Widget body click opens app normally
            val appIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val appPendingIntent = PendingIntent.getActivity(
                context,
                0,
                appIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, appPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun setupRefreshButton(context: Context, views: RemoteViews) {
            val refreshIntent = Intent(context, NetworkCheckerWidget::class.java).apply {
                action = ACTION_REFRESH
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)
        }

        private fun isDarkMode(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val uiMode = context.resources.configuration.uiMode
                (uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == 
                    android.content.res.Configuration.UI_MODE_NIGHT_YES
            } else {
                false
            }
        }

        private fun applyTheme(views: RemoteViews, isDarkMode: Boolean) {
            if (isDarkMode) {
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_dark)
                views.setTextColor(R.id.header_text, 0xFFE0E0E0.toInt())
                views.setTextColor(R.id.country_name, 0xFFFFFFFF.toInt())
                views.setTextColor(R.id.city_name, 0xFFB0B0B0.toInt())
                views.setTextColor(R.id.ip_address, 0xFFFFFFFF.toInt())
                views.setTextColor(R.id.last_update, 0xFF888888.toInt())
                views.setTextColor(R.id.error_message, 0xFFFF6B6B.toInt())
                views.setTextColor(R.id.loading_text, 0xFFE0E0E0.toInt())
                views.setTextColor(R.id.loading_percentage, 0xFFBB86FC.toInt())
                views.setTextColor(R.id.loading_debug, 0xFF888888.toInt())
                views.setTextColor(R.id.loading_timestamp, 0xFF666666.toInt())
                
                views.setInt(R.id.location_icon, "setColorFilter", 0xFFBB86FC.toInt())
                views.setInt(R.id.refresh_button, "setBackgroundResource", R.drawable.refresh_button_background_dark)
                views.setInt(R.id.ip_section, "setBackgroundResource", R.drawable.ip_box_background_dark)
            } else {
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background)
                views.setTextColor(R.id.header_text, 0xFF1C1B1F.toInt())
                views.setTextColor(R.id.country_name, 0xFF1C1B1F.toInt())
                views.setTextColor(R.id.city_name, 0xFF49454F.toInt())
                views.setTextColor(R.id.ip_address, 0xFF1C1B1F.toInt())
                views.setTextColor(R.id.last_update, 0xFF79747E.toInt())
                views.setTextColor(R.id.error_message, 0xFFB3261E.toInt())
                views.setTextColor(R.id.loading_text, 0xFF49454F.toInt())
                views.setTextColor(R.id.loading_percentage, 0xFF6750A4.toInt())
                views.setTextColor(R.id.loading_debug, 0xFF888888.toInt())
                views.setTextColor(R.id.loading_timestamp, 0xFFAAAAAA.toInt())
                
                views.setInt(R.id.location_icon, "setColorFilter", 0xFF6750A4.toInt())
                views.setInt(R.id.refresh_button, "setBackgroundResource", R.drawable.refresh_button_background)
                views.setInt(R.id.ip_section, "setBackgroundResource", R.drawable.ip_box_background)
            }
        }

        private fun maskIP(ip: String): String {
            if (ip == "Unknown" || ip.length <= 8) return ip
            val parts = ip.split(".")
            return if (parts.size == 4) {
                "${parts[0]}.***.***.${parts[3]}"
            } else {
                ip.take(4) + "***" + ip.takeLast(4)
            }
        }

        private fun formatLastUpdate(isoString: String): String {
            return try {
                val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
                val date = format.parse(isoString)
                val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
                "Updated: ${timeFormat.format(date ?: Date())}"
            } catch (e: Exception) {
                "Updated: --:--"
            }
        }
    }
}