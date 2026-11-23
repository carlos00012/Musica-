package com.musica.musica.widget

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import com.musica.musica.R

abstract class MusicWidgetProvider : HomeWidgetProvider() {
    abstract val layoutId: Int

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, layoutId)
            views.setTextViewText(
                R.id.widget_title,
                widgetData.getString("title", null) ?: "Tu música",
            )
            views.setTextViewText(
                R.id.widget_artist,
                widgetData.getString("artist", null) ?: "Reproduce una canción",
            )
            val artworkPath = widgetData.getString("artworkPath", null)
            val artwork = artworkPath?.let { BitmapFactory.decodeFile(it) }
            if (artwork != null) {
                views.setImageViewBitmap(R.id.widget_artwork, artwork)
                views.setViewVisibility(R.id.widget_artwork, View.VISIBLE)
                views.setViewVisibility(R.id.widget_artwork_placeholder, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_artwork, View.GONE)
                views.setViewVisibility(R.id.widget_artwork_placeholder, View.VISIBLE)
            }
            val playing = widgetData.getBoolean("isPlaying", false)
            views.setImageViewResource(
                R.id.widget_play,
                if (playing) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play,
            )
            views.setOnClickPendingIntent(
                R.id.widget_previous,
                actionIntent(context, "previous"),
            )
            views.setOnClickPendingIntent(
                R.id.widget_play,
                actionIntent(context, if (playing) "pause" else "play"),
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                actionIntent(context, "next"),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun actionIntent(context: Context, action: String): PendingIntent {
        val intent = Intent(context, PlayerWidgetActionReceiver::class.java)
            .setAction("com.musica.widget.$action")
        return PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

class CompactPlayerWidgetProvider : MusicWidgetProvider() {
    override val layoutId = R.layout.widget_compact
}

class ArtworkPlayerWidgetProvider : MusicWidgetProvider() {
    override val layoutId = R.layout.widget_artwork
}

class PlayerWidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val keyCode = when (intent.action) {
            "com.musica.widget.previous" -> android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS
            "com.musica.widget.next" -> android.view.KeyEvent.KEYCODE_MEDIA_NEXT
            "com.musica.widget.play" -> android.view.KeyEvent.KEYCODE_MEDIA_PLAY
            "com.musica.widget.pause" -> android.view.KeyEvent.KEYCODE_MEDIA_PAUSE
            else -> return
        }
        val mediaButton = Intent(Intent.ACTION_MEDIA_BUTTON)
            .setComponent(
                ComponentName(
                    context,
                    "com.ryanheise.audioservice.MediaButtonReceiver",
                ),
            )
            .putExtra(
                Intent.EXTRA_KEY_EVENT,
                android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, keyCode),
            )
        context.sendBroadcast(mediaButton)
    }
}
