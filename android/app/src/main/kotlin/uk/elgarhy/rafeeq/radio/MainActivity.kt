package uk.elgarhy.rafeeq.radio

import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var mediaSession: MediaSession
    private lateinit var channel: MethodChannel
    private val CHANNEL = "com.rafeeq.radio/media_session"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaSession = MediaSession(this, "RafeeqRadio")
        mediaSession.setFlags(
            MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
            MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
        mediaSession.setCallback(object : MediaSession.Callback() {
            override fun onPlay() { channel.invokeMethod("onToggle", null) }
            override fun onPause() { channel.invokeMethod("onToggle", null) }
            override fun onStop() { channel.invokeMethod("onToggle", null) }
        })
        mediaSession.isActive = true

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateMetadata" -> {
                    val title = call.argument<String>("title") ?: "رفيق راديو"
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
                                PlaybackState.ACTION_PLAY_PAUSE
                            )
                            .setState(
                                if (playing) PlaybackState.STATE_PLAYING
                                else PlaybackState.STATE_PAUSED,
                                PlaybackState.PLAYBACK_POSITION_UNKNOWN,
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
