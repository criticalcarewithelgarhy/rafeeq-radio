package uk.elgarhy.rafeeq.radio

import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var mediaSession: MediaSessionCompat
    private lateinit var channel: MethodChannel
    private val CHANNEL = "com.rafeeq.radio/media_session"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaSession = MediaSessionCompat(this, "RafeeqRadio")
        mediaSession.setFlags(
            MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
            MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() { channel.invokeMethod("onToggle", null) }
            override fun onPause() { channel.invokeMethod("onToggle", null) }
            override fun onPlayPause() { channel.invokeMethod("onToggle", null) }
            override fun onStop() { channel.invokeMethod("onToggle", null) }
        })
        mediaSession.isActive = true

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateMetadata" -> {
                    val title = call.argument<String>("title") ?: "رفيق راديو"
                    mediaSession.setMetadata(
                        MediaMetadataCompat.Builder()
                            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, "رفيق راديو")
                            .build()
                    )
                    result.success(null)
                }
                "updateState" -> {
                    val playing = call.argument<Boolean>("playing") ?: false
                    mediaSession.setPlaybackState(
                        PlaybackStateCompat.Builder()
                            .setActions(
                                PlaybackStateCompat.ACTION_PLAY or
                                PlaybackStateCompat.ACTION_PAUSE or
                                PlaybackStateCompat.ACTION_PLAY_PAUSE
                            )
                            .setState(
                                if (playing) PlaybackStateCompat.STATE_PLAYING
                                else PlaybackStateCompat.STATE_PAUSED,
                                PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN,
                                1f
                            )
                            .build()
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        mediaSession.isActive = false
        mediaSession.release()
        super.onDestroy()
    }
}
