package tv.bili.ui.player

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import androidx.compose.ui.graphics.ImageBitmap
import tv.bili.domain.player.PlaySource
import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * Manual integration probe; requires VLC_HOME and a local MP4.
 * Run with: -Dtest.video=<file> or VLC_TEST_VIDEO=<file>.
 */
class VlcjPlayerControllerTest {

    @Test
    fun localMp4ProducesFrames() = runBlocking {
        val video = System.getProperty("test.video")
            ?: System.getenv("VLC_TEST_VIDEO")
            ?: return@runBlocking
        val file = File(video)
        if (!file.isFile) return@runBlocking

        assertTrue(VlcSupport.discover(), "VLC not found; set VLC_HOME")

        val controller = VlcjPlayerController()
        try {
            val frames = mutableListOf<ImageBitmap>()
            val job = launch(Dispatchers.Default) {
                controller.frame.filterNotNull().take(3).toList(frames)
            }
            controller.setSource(PlaySource(videoUrl = file.absolutePath))
            withTimeout(25_000L) { job.join() }
            println("got ${frames.size} frames: ${frames.map { "${it.width}x${it.height}" }}")
            assertTrue(frames.isNotEmpty(), "no frames rendered")
        } finally {
            controller.release()
        }
    }

    @Test
    fun bilibiliDashProducesFrames() = runBlocking {
        val propsPath = System.getProperty("test.props")
            ?: System.getenv("VLC_TEST_PROPS")
            ?: return@runBlocking
        val props = java.util.Properties()
        File(propsPath).inputStream().use(props::load)
        val videoUrl = props.getProperty("video") ?: return@runBlocking
        val audioUrl = props.getProperty("audio")
        val backupVideoUrls = props.getProperty("videoBackups").orEmpty()
            .split('|').filter { it.isNotBlank() }
        val backupAudioUrls = props.getProperty("audioBackups").orEmpty()
            .split('|').filter { it.isNotBlank() }

        assertTrue(VlcSupport.discover(), "VLC not found; set VLC_HOME")

        val controller = VlcjPlayerController()
        try {
            val frames = mutableListOf<ImageBitmap>()
            val job = launch(Dispatchers.Default) {
                controller.frame.filterNotNull().take(3).toList(frames)
            }
            controller.setSource(
                PlaySource(
                    videoUrl = videoUrl,
                    audioUrl = audioUrl,
                    backupVideoUrls = backupVideoUrls,
                    backupAudioUrls = backupAudioUrls,
                    headers = mapOf(
                        "Referer" to "https://www.bilibili.com",
                        "User-Agent" to "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
                            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
                    ),
                ),
            )
            withTimeout(45_000L) { job.join() }
            println("bili got ${frames.size} frames: ${frames.map { "${it.width}x${it.height}" }}")
            assertTrue(frames.isNotEmpty(), "no frames rendered")
        } finally {
            controller.release()
        }
    }
}
