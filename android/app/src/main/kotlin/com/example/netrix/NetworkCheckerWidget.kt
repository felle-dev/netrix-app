package com.example.netrix

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.os.Build
import android.view.View
import java.text.SimpleDateFormat
import java.util.*

/**
 * Network Checker Widget Provider - Enhanced Version
 * Features: Dark/Light theme support, Loading state, No app opening on refresh
 */
class NetworkCheckerWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_REFRESH -> {
                // Show loading state immediately
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, NetworkCheckerWidget::class.java)
                )
                
                for (appWidgetId in appWidgetIds) {
                    showLoadingState(context, appWidgetManager, appWidgetId)
                }
                
                // Trigger background refresh via home_widget plugin
                // The Flutter app will update via HomeWidget.saveWidgetData()
                // which will automatically call updateAppWidget
                val refreshIntent = Intent("es.antonborri.home_widget.action.UPDATE").apply {
                    putExtra("triggerUpdate", true)
                }
                context.sendBroadcast(refreshIntent)
            }
        }
    }

    companion object {
        private const val ACTION_REFRESH = "com.example.netrix.REFRESH"
        private const val PREFS_NAME = "HomeWidgetPreferences"

        private fun showLoadingState(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val isDarkMode = isDarkMode(context)
            val views = RemoteViews(context.packageName, R.layout.network_checker_widget)
            
            // Hide all content
            views.setViewVisibility(R.id.error_layout, View.GONE)
            views.setViewVisibility(R.id.main_content, View.GONE)
            views.setViewVisibility(R.id.ip_section, View.GONE)
            views.setViewVisibility(R.id.tor_banner, View.GONE)
            
            // Show loading indicator
            views.setViewVisibility(R.id.loading_layout, View.VISIBLE)
            
            // Apply theme
            applyTheme(views, isDarkMode)
            
            // Keep refresh button active
            setupRefreshButton(context, views)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            // Check if loading
            val isLoading = prefs.getBoolean("isLoading", false)
            if (isLoading) {
                showLoadingState(context, appWidgetManager, appWidgetId)
                return
            }
            
            // Read data from SharedPreferences
            val hasError = prefs.getBoolean("hasError", false)
            val country = prefs.getString("country", "Unknown") ?: "Unknown"
            val city = prefs.getString("city", "") ?: ""
            val publicIP = prefs.getString("publicIP", "•••.•••.•••.•••") ?: "•••.•••.•••.•••"
            val flag = prefs.getString("flag", "🌍") ?: "🌍"
            val isTor = prefs.getBoolean("isTor", false)
            val lastUpdate = prefs.getString("lastUpdate", null)
            val errorMessage = prefs.getString("errorMessage", "Unable to load")
            
            val isDarkMode = isDarkMode(context)
            val views = RemoteViews(context.packageName, R.layout.network_checker_widget)

            // Hide loading
            views.setViewVisibility(R.id.loading_layout, View.GONE)

            if (hasError) {
                // Show error state
                views.setViewVisibility(R.id.error_layout, View.VISIBLE)
                views.setViewVisibility(R.id.header_layout, View.GONE)
                views.setViewVisibility(R.id.main_content, View.GONE)
                views.setViewVisibility(R.id.ip_section, View.GONE)
                views.setViewVisibility(R.id.tor_banner, View.GONE)
                views.setTextViewText(R.id.error_message, errorMessage)
            } else {
                // Show normal state
                views.setViewVisibility(R.id.error_layout, View.GONE)
                views.setViewVisibility(R.id.header_layout, View.VISIBLE)
                views.setViewVisibility(R.id.main_content, View.VISIBLE)
                views.setViewVisibility(R.id.ip_section, View.VISIBLE)

                // Set header
                val headerText = if (isTor) "Your Tor Exit Location" else "Your Location"
                views.setTextViewText(R.id.header_text, headerText)

                // Set flag and location
                views.setTextViewText(R.id.country_flag, flag)
                views.setTextViewText(R.id.country_name, country)
                
                if (city.isNotEmpty() && city != "Unknown") {
                    views.setViewVisibility(R.id.city_name, View.VISIBLE)
                    views.setTextViewText(R.id.city_name, city)
                } else {
                    views.setViewVisibility(R.id.city_name, View.GONE)
                }

                // Set IP (masked)
                val maskedIP = maskIP(publicIP)
                views.setTextViewText(R.id.ip_address, maskedIP)

                // Show/hide Tor banner
                if (isTor) {
                    views.setViewVisibility(R.id.tor_banner, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.tor_banner, View.GONE)
                }

                // Set last update time
                if (lastUpdate != null) {
                    val updateText = formatLastUpdate(lastUpdate)
                    views.setTextViewText(R.id.last_update, updateText)
                }
            }

            // Apply theme colors
            applyTheme(views, isDarkMode)

            // Set refresh button
            setupRefreshButton(context, views)

            // Set widget click to open app
            val appIntent = Intent(context, MainActivity::class.java)
            val appPendingIntent = PendingIntent.getActivity(
                context,
                0,
                appIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, appPendingIntent)

            // Update the widget
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
                // Dark theme colors
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_dark)
                views.setTextColor(R.id.header_text, 0xFFE0E0E0.toInt())
                views.setTextColor(R.id.country_name, 0xFFFFFFFF.toInt())
                views.setTextColor(R.id.city_name, 0xFFB0B0B0.toInt())
                views.setTextColor(R.id.ip_address, 0xFFFFFFFF.toInt())
                views.setTextColor(R.id.last_update, 0xFF888888.toInt())
                views.setTextColor(R.id.error_message, 0xFFFF6B6B.toInt())
                views.setTextColor(R.id.loading_text, 0xFFE0E0E0.toInt())
                
                // Update icon tints for dark mode
                views.setInt(R.id.location_icon, "setColorFilter", 0xFFBB86FC.toInt())
                views.setInt(R.id.refresh_button, "setBackgroundResource", R.drawable.refresh_button_background_dark)
                views.setInt(R.id.ip_section, "setBackgroundResource", R.drawable.ip_box_background_dark)
            } else {
                // Light theme colors (default)
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background)
                views.setTextColor(R.id.header_text, 0xFF1C1B1F.toInt())
                views.setTextColor(R.id.country_name, 0xFF1C1B1F.toInt())
                views.setTextColor(R.id.city_name, 0xFF49454F.toInt())
                views.setTextColor(R.id.ip_address, 0xFF1C1B1F.toInt())
                views.setTextColor(R.id.last_update, 0xFF79747E.toInt())
                views.setTextColor(R.id.error_message, 0xFFB3261E.toInt())
                views.setTextColor(R.id.loading_text, 0xFF49454F.toInt())
                
                // Light mode icon tints
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