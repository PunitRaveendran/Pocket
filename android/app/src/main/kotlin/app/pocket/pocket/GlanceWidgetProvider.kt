package app.pocket.pocket

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class GlanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.glance_widget).apply {
                val amount = widgetData.getString("amount_text", "₹0 left today") ?: "₹0 left today"
                val caption = widgetData.getString("caption_text", "Allowance") ?: "Allowance"
                val progress = widgetData.getInt("progress_percent", 50)

                setTextViewText(R.id.widget_amount, amount)
                setTextViewText(R.id.widget_caption, caption)
                setProgressBar(R.id.widget_progress, 100, progress.coerceIn(0, 100), false)

                // Launch Pocket on widget tap
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "app.pocket.pocket.QUICK_SPEND"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
