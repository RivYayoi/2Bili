package tv.bili.ui.player

import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.toComposeImageBitmap
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import tv.bili.domain.player.PlaySource
import tv.bili.domain.player.PlayerController
import tv.bili.domain.player.PlayerState
import uk.co.caprica.vlcj.factory.MediaPlayerFactory
import uk.co.caprica.vlcj.player.base.MediaPlayer
import uk.co.caprica.vlcj.player.base.MediaPlayerEventAdapter
import uk.co.caprica.vlcj.player.embedded.EmbeddedMediaPlayer
import uk.co.caprica.vlcj.player.embedded.videosurface.CallbackVideoSurface
import uk.co.caprica.vlcj.player.embedded.videosurface.VideoSurfaceAdapters
import uk.co.caprica.vlcj.player.embedded.videosurface.callback.BufferFormat
import uk.co.caprica.vlcj.player.embedded.videosurface.callback.BufferFormatCallbackAdapter
import uk.co.caprica.vlcj.player.embedded.videosurface.callback.RenderCallbackAdapter
import uk.co.caprica.vlcj.player.embedded.videosurface.callback.format.RV32BufferFormat
import java.awt.image.BufferedImage
import java.awt.image.DataBufferInt
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * Desktop player: VLC via vlcj's CallbackVideoSurface.
 *
 * Why callback rendering instead of a heavyweight Canvas?
 *  - the frames arrive as an IntArray, which we can turn into an ImageBitmap
 *    and draw with Compose, so the danmaku overlay is a normal sibling node;
 *  - no AWT/Swing component interop, no z-order problems, no window resize
 *    flicker on Windows.
 *
 * DASH audio is attached with :input-slave=<audio-url>, which makes VLC play
 * the two HTTP streams as one timeline.
 *
 * Reliability notes:
 *  - Bilibili returns several CDN URLs per stream. The primary MCDN host is
 *    not reachable from every network (TLS handshake timeout), so the data
 *    layer passes the upos backups and this controller retries them.
 *  - Hardware decoding (D3D11VA/DXVA2) can produce "get_buffer() failed" and
 *    a permanently black vmem surface on some Windows drivers. We force
 *    software decoding; it is fast enough for 1080p on a desktop.
 *  - If a stream starts but no frame arrives, a watchdog switches to the next
 *    URL instead of leaving the user with a silent black rectangle.
 *
 * Concurrency: VLCJ invokes event callbacks on its own thread. All state that
 * touches the player (URL indices, play/retry decisions) is confined to the
 * single watchdog thread. Public methods only bump an atomic generation and
 * submit work, so no Java monitor is ever held while VLC is re-entered.
 */
class VlcjPlayerController : PlayerController {

    private val _state = MutableStateFlow(PlayerState())
    override val state: StateFlow<PlayerState> = _state.asStateFlow()

    private val _frame = MutableStateFlow<ImageBitmap?>(null)
    val frame: StateFlow<ImageBitmap?> = _frame.asStateFlow()

    private val factory = MediaPlayerFactory(
        VlcSupport.discovery(),
        *buildList {
            add("--no-video-title-show")
            add("--network-caching=1500")
            add("--avcodec-hw=none")
            // GUI builds have no console; always keep a file log so a black
            // screen can be diagnosed on the user's machine.
            add("--file-logging")
            add("--logfile=${PlayerDebugLog.vlcLogFile.absolutePath}")
            add("--verbose=2")
            // :input-slave does not always inherit media-level HTTP options;
            // make the headers global so the audio slave gets them too.
            add("--http-referrer=$DEFAULT_REFERER")
            add("--http-user-agent=$DEFAULT_UA")
        }.toTypedArray(),
    )

    private val player: EmbeddedMediaPlayer = factory.mediaPlayers().newEmbeddedMediaPlayer()

    private var image: BufferedImage? = null
    private var frameErrorLogged = false

    @Volatile
    private var renderedFrames = 0L

    private val generation = AtomicLong(0L)
    private val retryPending = AtomicBoolean(false)

    // Confined to the watchdog thread.
    private var videoUrls: List<String> = emptyList()
    private var audioUrls: List<String> = emptyList()
    private var headers: Map<String, String> = emptyMap()
    private var videoIndex = 0
    private var audioIndex = 0
    private var audioDisabled = false

    private val watchdog = Executors.newSingleThreadScheduledExecutor { runnable ->
        Thread(runnable, "2bili-vlc-watchdog").apply { isDaemon = true }
    }

    @Volatile
    private var watchdogTask: ScheduledFuture<*>? = null

    private val renderCallback = object : RenderCallbackAdapter() {
        override fun onDisplay(mediaPlayer: MediaPlayer, buffer: IntArray) {
            val source = image ?: return
            // The native buffer is reused by VLC, so copy before handing it to Skia.
            val bitmap = runCatching {
                val copy = BufferedImage(source.width, source.height, BufferedImage.TYPE_INT_RGB)
                copy.setRGB(0, 0, source.width, source.height, buffer, 0, source.width)
                copy.toComposeImageBitmap()
            }.getOrElse { error ->
                if (!frameErrorLogged) {
                    frameErrorLogged = true
                    System.err.println("[2bili] VLC frame conversion failed: ${error.message}")
                }
                return
            }
            _frame.value = bitmap
            renderedFrames++
            if (renderedFrames == 1L || renderedFrames % 300L == 0L) {
                PlayerDebugLog.log("frame #$renderedFrames ${source.width}x${source.height}")
            }
        }
    }

    private val formatCallback = object : BufferFormatCallbackAdapter() {
        override fun getBufferFormat(sourceWidth: Int, sourceHeight: Int): BufferFormat {
            val width = sourceWidth.coerceAtLeast(2)
            val height = sourceHeight.coerceAtLeast(2)

            PlayerDebugLog.log("format ${width}x${height}")
            val next = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)
            image = next
            renderCallback.setBuffer((next.raster.dataBuffer as DataBufferInt).data)

            _state.update { it.copy(videoWidth = width, videoHeight = height) }
            return RV32BufferFormat(width, height)
        }
    }

    private val surface = CallbackVideoSurface(
        formatCallback,
        renderCallback,
        true,
        VideoSurfaceAdapters.getVideoSurfaceAdapter(),
    )

    init {
        PlayerDebugLog.log("VlcjPlayerController init; vlcLog=${PlayerDebugLog.vlcLogFile.absolutePath}")
        player.videoSurface().set(surface)

        player.events().addMediaPlayerEventListener(
            object : MediaPlayerEventAdapter() {
                override fun opening(mediaPlayer: MediaPlayer) {
                    PlayerDebugLog.log("event opening")
                }

                override fun buffering(mediaPlayer: MediaPlayer, newCache: Float) {
                    if (newCache >= 99f) {
                        PlayerDebugLog.log("event buffering=${newCache.toInt()}%")
                    }
                }

                override fun playing(mediaPlayer: MediaPlayer) {
                    PlayerDebugLog.log("event playing")
                    _state.update {
                        it.copy(phase = PlayerState.Phase.Ready, isPlaying = true, error = null)
                    }
                }

                override fun paused(mediaPlayer: MediaPlayer) {
                    PlayerDebugLog.log("event paused")
                    _state.update { it.copy(isPlaying = false) }
                }

                override fun stopped(mediaPlayer: MediaPlayer) {
                    PlayerDebugLog.log("event stopped")
                    _state.update { it.copy(isPlaying = false) }
                }

                override fun finished(mediaPlayer: MediaPlayer) {
                    PlayerDebugLog.log("event finished")
                    _state.update {
                        it.copy(phase = PlayerState.Phase.Ended, isPlaying = false)
                    }
                }

                override fun timeChanged(mediaPlayer: MediaPlayer, newTime: Long) {
                    _state.update { it.copy(positionMs = newTime.coerceAtLeast(0L)) }
                }

                override fun lengthChanged(mediaPlayer: MediaPlayer, newLength: Long) {
                    PlayerDebugLog.log("event length=${newLength}ms")
                    _state.update { it.copy(durationMs = newLength.coerceAtLeast(0L)) }
                }

                override fun videoOutput(mediaPlayer: MediaPlayer, newCount: Int) {
                    PlayerDebugLog.log("event videoOutput=$newCount")
                }

                override fun error(mediaPlayer: MediaPlayer) {
                    PlayerDebugLog.log("event error")
                    requestRetry()
                }
            },
        )
    }

    override fun setSource(source: PlaySource) {
        val gen = generation.incrementAndGet()
        retryPending.set(false)
        runCatching {
            watchdog.execute {
                if (gen != generation.get()) return@execute

                videoUrls = (listOf(source.videoUrl) + source.backupVideoUrls)
                    .filter { it.isNotBlank() }
                    .distinct()
                audioUrls = (listOfNotNull(source.audioUrl) + source.backupAudioUrls)
                    .filter { it.isNotBlank() }
                    .distinct()
                headers = source.headers
                videoIndex = 0
                audioIndex = 0
                audioDisabled = false
                renderedFrames = 0

                PlayerDebugLog.log(
                    "setSource dash=${source.isDash} videoUrls=${videoUrls.size} audioUrls=${audioUrls.size}",
                )
                videoUrls.forEachIndexed { index, url ->
                    PlayerDebugLog.log("  video[$index]=$url")
                }
                audioUrls.forEachIndexed { index, url ->
                    PlayerDebugLog.log("  audio[$index]=$url")
                }

                _state.update {
                    it.copy(
                        phase = PlayerState.Phase.Preparing,
                        isPlaying = false,
                        error = null,
                        positionMs = 0L,
                    )
                }

                playCurrent(gen)
            }
        }
    }

    private fun playCurrent(gen: Long) {
        if (gen != generation.get()) return

        val video = videoUrls.getOrNull(videoIndex)
        if (video == null) {
            fail("没有可用的视频地址")
            return
        }

        val audio = if (audioDisabled) null else audioUrls.getOrNull(audioIndex)
        val options = buildList {
            add(":http-referrer=${headers["Referer"] ?: DEFAULT_REFERER}")
            add(":http-user-agent=${headers["User-Agent"] ?: DEFAULT_UA}")
            audio?.let { add(":input-slave=$it") }
        }

        renderedFrames = 0
        retryPending.set(false)
        _state.update {
            it.copy(phase = PlayerState.Phase.Preparing, isPlaying = false, error = null)
        }

        PlayerDebugLog.log(
            "play videoIndex=$videoIndex/$videoUrls audioIndex=$audioIndex/$audioUrls\n" +
                "  video=$video\n" +
                "  audio=$audio",
        )
        val started = runCatching {
            player.media().play(video, *options.toTypedArray())
        }.getOrElse { error ->
            PlayerDebugLog.log("play threw: ${error::class.simpleName}: ${error.message}")
            false
        }
        PlayerDebugLog.log("play returned=$started")

        if (!started) {
            if (videoIndex + 1 < videoUrls.size) {
                videoIndex++
                playCurrent(gen)
            } else {
                fail("视频流无法播放，请稍后重试")
            }
            return
        }

        scheduleWatchdog(gen)
    }

    private fun scheduleWatchdog(gen: Long) {
        watchdogTask?.cancel(false)
        watchdogTask = runCatching {
            watchdog.schedule(
                { checkPlayback(gen) },
                WATCHDOG_DELAY_SECONDS,
                TimeUnit.SECONDS,
            )
        }.getOrNull()
    }

    private fun checkPlayback(gen: Long) {
        if (gen != generation.get()) return

        val snapshot = _state.value
        if (snapshot.phase == PlayerState.Phase.Error ||
            snapshot.phase == PlayerState.Phase.Ended ||
            snapshot.phase == PlayerState.Phase.Idle
        ) {
            return
        }
        // Paused before the first frame: do not rotate URLs under the user.
        if (snapshot.phase == PlayerState.Phase.Ready && !snapshot.isPlaying) return

        val audioTracks = runCatching { player.audio().trackCount() }.getOrDefault(-1)
        PlayerDebugLog.log(
            "watchdog phase=${snapshot.phase} playing=${snapshot.isPlaying} " +
                "frames=$renderedFrames video=$videoIndex/${videoUrls.size} " +
                "audio=$audioIndex/${audioUrls.size} audioTracks=$audioTracks",
        )

        if (renderedFrames == 0L) {
            recoverFromFailure(gen, audioTracks)
            return
        }

        // Video is visible but the audio slave failed; try another audio URL.
        if (!audioDisabled &&
            audioUrls.size > 1 &&
            audioIndex + 1 < audioUrls.size &&
            audioTracks == 0
        ) {
            audioIndex++
            playCurrent(gen)
        }
    }

    /**
     * Classify a "no frames" / VLC error and recover in the least disruptive
     * order:
     *  1. a failed :input-slave destroys the video output in VLC 3, so try the
     *     next audio URL first;
     *  2. if every audio URL failed, retry the same video without audio;
     *  3. only then rotate the video URL.
     */
    private fun recoverFromFailure(gen: Long, audioTracks: Int) {
        if (!audioDisabled && audioTracks <= 0 && audioIndex + 1 < audioUrls.size) {
            audioIndex++
            playCurrent(gen)
            return
        }
        if (!audioDisabled && audioTracks <= 0 && audioUrls.isNotEmpty()) {
            // A silent video is much better than a black screen.
            PlayerDebugLog.log("all audio URLs failed; retrying video without audio")
            audioDisabled = true
            audioIndex = 0
            playCurrent(gen)
            return
        }
        if (videoIndex + 1 < videoUrls.size) {
            videoIndex++
            audioIndex = 0
            playCurrent(gen)
            return
        }
        fail("视频流无法播放，请稍后重试")
    }

    private fun requestRetry() {
        val gen = generation.get()
        if (!retryPending.compareAndSet(false, true)) return
        runCatching {
            watchdog.execute {
                retryPending.set(false)
                if (gen != generation.get()) return@execute
                val audioTracks = runCatching { player.audio().trackCount() }.getOrDefault(-1)
                recoverFromFailure(gen, audioTracks)
            }
        }
    }

    private fun fail(message: String) {
        PlayerDebugLog.log("FAIL: $message (videoIndex=$videoIndex/${videoUrls.size}, audioIndex=$audioIndex/${audioUrls.size})")
        runCatching { player.controls().stop() }
        _state.update {
            it.copy(phase = PlayerState.Phase.Error, isPlaying = false, error = message)
        }
    }

    override fun play() {
        player.controls().play()
    }

    override fun pause() {
        player.controls().pause()
    }

    override fun seekTo(positionMs: Long) {
        player.controls().setTime(positionMs.coerceAtLeast(0L))
    }

    override fun setSpeed(speed: Float) {
        val clamped = speed.coerceIn(0.25f, 4f)
        player.controls().setRate(clamped)
        _state.update { it.copy(speed = clamped) }
    }

    override fun release() {
        generation.incrementAndGet()
        retryPending.set(true)
        watchdogTask?.cancel(false)
        watchdog.shutdownNow()
        runCatching { player.controls().stop() }
        runCatching { player.release() }
        runCatching { factory.release() }
    }

    private companion object {
        const val DEFAULT_REFERER = "https://www.bilibili.com"
        const val DEFAULT_UA =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

        const val WATCHDOG_DELAY_SECONDS = 8L
    }
}
