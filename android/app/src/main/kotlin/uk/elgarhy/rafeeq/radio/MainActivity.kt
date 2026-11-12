package uk.elgarhy.rafeeq.radio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.drawable.Icon
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var mediaSession: MediaSession
    private lateinit var channel: MethodChannel
    private val CHANNEL = "com.rafeeq.radio/media_session"
    private val MEDIA_CHANNEL_ID = "rafeeq_media_controls"
    private val MEDIA_NOTIF_ID = 9001
    private val ACTION_TOGGLE = "uk.elgarhy.rafeeq.radio.TOGGLE"
    private val ACTION_NEXT = "uk.elgarhy.rafeeq.radio.NEXT"
    private var currentTitle = "رفيق راديو"

    private val toggleReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_TOGGLE -> channel.invokeMethod("onToggle", null)
                ACTION_NEXT -> channel.invokeMethod("onNext", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannel()

        val filter = IntentFilter().apply {
            addAction(ACTION_TOGGLE)
            addAction(ACTION_NEXT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(toggleReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(toggleReceiver, filter)
        }

        mediaSession = MediaSession(this, "RafeeqRadio")
        mediaSession.setFlags(
            MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
            MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
        mediaSession.setCallback(object : MediaSession.Callback() {
            override fun onPlay() { channel.invokeMethod("onToggle", null) }
            override fun onPause() { channel.invokeMethod("onToggle", null) }
            override fun onStop() { channel.invokeMethod("onToggle", null) }
            override fun onSkipToNext() { channel.invokeMethod("onNext", null) }
        })
        mediaSession.isActive = true

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateMetadata" -> {
                    val title = call.argument<String>("title") ?: "رفيق راديو"
                    currentTitle = title
                    mediaSession.setMetadata(
                        MediaMetadata.Builder()
                            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                            .putString(MediaMetadata.METADATA_KEY_ARTIST, "رفيق راديو")
                            .build()
                    )
                    result.success(null)
                }
                "updateState" -> {
                    val playing = call.argument<Boolean>("playing") ?: false
                    mediaSession.setPlaybackState(
                        PlaybackState.Builder()
                            .setActions(
                                PlaybackState.ACTION_PLAY or
                                PlaybackState.ACTION_PAUSE or
                                PlaybackState.ACTION_PLAY_PAUSE or
                                PlaybackState.ACTION_SKIP_TO_NEXT
                            )
                            .setState(
                                if (playing) PlaybackState.STATE_PLAYING
                                else PlaybackState.STATE_PAUSED,
                                PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                                1f
                            )
                            .build()
                    )
                    showMediaNotification(currentTitle, playing)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        val ch = NotificationChannel(
            MEDIA_CHANNEL_ID,
            "وسائط رفيق راديو",
            NotificationManager.IMPORTANCE_LOW
        ).apply { setShowBadge(false) }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(ch)
    }

    private fun togglePendingIntent(): PendingIntent {
        val intent = Intent(ACTION_TOGGLE).setPackage(packageName)
        return PendingIntent.getBroadcast(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun nextPendingIntent(): PendingIntent {
        val intent = Intent(ACTION_NEXT).setPackage(packageName)
        return PendingIntent.getBroadcast(
            this, 1, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun showMediaNotification(title: String, playing: Boolean) {
        val togglePi = togglePendingIntent()
        val nextPi = nextPendingIntent()
        val playPauseIcon = if (playing) android.R.drawable.ic_media_pause
                            else android.R.drawable.ic_media_play
        val playPauseLabel = if (playing) "إيقاف" else "تشغيل"
        val statusText = if (playing) "▶ يعزف الآن" else "⏸ متوقف"

        val notification = Notification.Builder(this, MEDIA_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(statusText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(playing)
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1)
            )
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, playPauseIcon), playPauseLabel, togglePi
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, android.R.drawable.ic_media_next), "التالي", nextPi
                ).build()
            )
            .build()

        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .notify(MEDIA_NOTIF_ID, notification)
    }

    override fun onDestroy() {
        unregisterReceiver(toggleReceiver)
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(MEDIA_NOTIF_ID)
        mediaSession.isActive = false
        mediaSession.release()
        super.onDestroy()
    }
}
