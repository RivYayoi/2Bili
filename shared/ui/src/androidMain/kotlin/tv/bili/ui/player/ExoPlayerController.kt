package tv.bili.ui.player

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import tv.bili.domain.player.PlaySource
import tv.bili.domain.player.PlayerController
import tv.bili.domain.player.PlayerState

/**
 * Android player: Media3 ExoPlayer.
 *
 * DASH is merged locally (MergingMediaSource) instead of relying on a DASH
 * manifest, because bilibili hands us two independent MP4 URLs.
 */
@OptIn(UnstableApi::class)
class ExoPlayerController(context: Context) : PlayerController {

    val player: ExoPlayer = ExoPlayer.Builder(context).build()

    private val _state = MutableStateFlow(PlayerState())
    override val state: StateFlow<PlayerState> = _state.asStateFlow()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    init {
        player.addListener(
            object : Player.Listener {
                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    _state.update { it.copy(isPlaying = isPlaying) }
                }

                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_BUFFERING -> _state.update {
                            it.copy(phase = PlayerState.Phase.Preparing)
                        }

                        Player.STATE_READY -> _state.update {
                            it.copy(phase = PlayerState.Phase.Ready, error = null)
                        }

                        Player.STATE_ENDED -> _state.update {
                            it.copy(phase = PlayerState.Phase.Ended, isPlaying = false)
                        }

                        Player.STATE_IDLE -> Unit
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    _state.update {
                        it.copy(
                            phase = PlayerState.Phase.Error,
                            isPlaying = false,
                            error = error.message,
                        )
                    }
                }
            },
        )

        scope.launch {
            while (isActive) {
                val duration = player.duration
                _state.update {
                    it.copy(
                        positionMs = player.currentPosition.coerceAtLeast(0L),
                        durationMs = if (duration == C.TIME_UNSET || duration < 0L) 0L else duration,
                    )
                }
                delay(250L)
            }
        }
    }

    override fun setSource(source: PlaySource) {
        _state.update { it.copy(phase = PlayerState.Phase.Preparing, error = null) }

        val dataSourceFactory = DefaultHttpDataSource.Factory()
            .setDefaultRequestProperties(source.headers)
            .setAllowCrossProtocolRedirects(true)

        val video = ProgressiveMediaSource.Factory(dataSourceFactory)
            .createMediaSource(MediaItem.fromUri(source.videoUrl))

        val mediaSource = source.audioUrl?.takeIf { it.isNotBlank() }?.let { audioUrl ->
            val audio = ProgressiveMediaSource.Factory(dataSourceFactory)
                .createMediaSource(MediaItem.fromUri(audioUrl))
            MergingMediaSource(video, audio)
        } ?: video

        player.setMediaSource(mediaSource)
        player.prepare()

        if (source.startPositionMs > 0L) {
            player.seekTo(source.startPositionMs)
        }
    }

    override fun play() {
        player.play()
    }

    override fun pause() {
        player.pause()
    }

    override fun seekTo(positionMs: Long) {
        player.seekTo(positionMs.coerceAtLeast(0L))
    }

    override fun setSpeed(speed: Float) {
        val clamped = speed.coerceIn(0.25f, 4f)
        player.setPlaybackSpeed(clamped)
        _state.update { it.copy(speed = clamped) }
    }

    override fun release() {
        scope.cancel()
        player.release()
    }
}
