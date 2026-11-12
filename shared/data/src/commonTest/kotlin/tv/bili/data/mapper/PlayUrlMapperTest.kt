package tv.bili.data.mapper

import tv.bili.data.dto.DashDto
import tv.bili.data.dto.DashStreamDto
import tv.bili.data.dto.PlayUrlDto
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PlayUrlMapperTest {

    @Test
    fun prefersAvcOverHevcAndAv1() {
        val playUrl = PlayUrlDto(
            quality = 64,
            acceptQuality = listOf(64, 32),
            acceptDescription = listOf("720P", "480P"),
            dash = DashDto(
                video = listOf(
                    video(id = 32, codecid = 7, codecs = "avc1.640033", bw = 100, base = "https://mcdn.example/avc", backup = listOf("https://upos-sz-mirror.example/avc")),
                    video(id = 32, codecid = 12, codecs = "hvc1.1.6.L120.90", bw = 900, base = "https://mcdn.example/hevc"),
                    video(id = 32, codecid = 13, codecs = "av01.0.08M.08", bw = 800, base = "https://mcdn.example/av1"),
                    video(id = 16, codecid = 7, codecs = "avc1.640033", bw = 50, base = "https://mcdn.example/avc-360"),
                ),
                audio = listOf(
                    audio(id = 30232, base = "https://mcdn.example/audio", backup = listOf("https://upos-sz-mirror.example/audio")),
                ),
            ),
        ).toDomain()

        val source = playUrl.sources.getValue(32)
        assertEquals("https://mcdn.example/avc", source.videoUrl)
        assertEquals(listOf("https://upos-sz-mirror.example/avc"), source.backupVideoUrls)
        // The direct upos mirror is preferred for audio because the MCDN host
        // frequently fails its TLS handshake.
        assertEquals("https://upos-sz-mirror.example/audio", source.audioUrl)
        assertEquals(listOf("https://mcdn.example/audio"), source.backupAudioUrls)
    }

    @Test
    fun prefersReachableAudioHostAcrossVariants() {
        val playUrl = PlayUrlDto(
            quality = 32,
            acceptQuality = listOf(32),
            acceptDescription = listOf("480P"),
            dash = DashDto(
                video = listOf(
                    video(id = 32, codecid = 7, codecs = "avc1.640033", bw = 100, base = "https://mcdn.example/avc"),
                ),
                audio = listOf(
                    // The preferred 132 kbps variant only advertises the flaky
                    // MCDN host in this response.
                    audio(id = 30232, base = "https://mcdn.example/audio-132"),
                    // A higher bitrate variant has a reachable direct mirror.
                    audio(id = 30280, base = "https://upos-sz-mirror.example/audio-192"),
                ),
            ),
        ).toDomain()

        val source = playUrl.sources.getValue(32)
        assertEquals("https://upos-sz-mirror.example/audio-192", source.audioUrl)
        assertEquals(listOf("https://mcdn.example/audio-132"), source.backupAudioUrls)
    }

    @Test
    fun fallsBackToHevcWhenAvcIsMissing() {
        val playUrl = PlayUrlDto(
            quality = 64,
            acceptQuality = listOf(64),
            acceptDescription = listOf("720P"),
            dash = DashDto(
                video = listOf(
                    video(id = 64, codecid = 13, codecs = "av01.0.08M.08", bw = 900, base = "av1"),
                    video(id = 64, codecid = 12, codecs = "hvc1.1.6.L120.90", bw = 500, base = "hevc"),
                ),
            ),
        ).toDomain()

        assertEquals("hevc", playUrl.sources.getValue(64).videoUrl)
    }

    @Test
    fun prefersDirectBackupForHevc() {
        val playUrl = PlayUrlDto(
            quality = 80,
            acceptQuality = listOf(80),
            acceptDescription = listOf("1080P"),
            dash = DashDto(
                video = listOf(
                    video(
                        id = 80,
                        codecid = 12,
                        codecs = "hvc1.1.6.L120.90",
                        bw = 900,
                        base = "https://mcdn.example/hevc",
                        backup = listOf("https://upos-sz-mirror.example/hevc"),
                    ),
                ),
            ),
        ).toDomain()

        val source = playUrl.sources.getValue(80)
        // The HEVC primary MCDN host commonly times out; start with upos.
        assertEquals("https://upos-sz-mirror.example/hevc", source.videoUrl)
        assertEquals(listOf("https://mcdn.example/hevc"), source.backupVideoUrls)
    }

    @Test
    fun skipsDolbyVision() {
        val playUrl = PlayUrlDto(
            quality = 126,
            acceptQuality = listOf(126),
            acceptDescription = listOf("杜比视界"),
            dash = DashDto(
                video = listOf(
                    video(id = 126, codecid = 12, codecs = "dvh1.08.07", bw = 2000, base = "dolby-vision"),
                    video(id = 126, codecid = 12, codecs = "hvc1.1.6.L120.90", bw = 800, base = "hevc-sdr"),
                ),
            ),
        ).toDomain()

        assertEquals("hevc-sdr", playUrl.sources.getValue(126).videoUrl)
    }

    @Test
    fun onlyAdvertisesQualitiesWithAStream() {
        val playUrl = PlayUrlDto(
            quality = 64,
            acceptQuality = listOf(112, 80, 64, 32),
            acceptDescription = listOf("1080P+", "1080P", "720P", "480P"),
            dash = DashDto(
                video = listOf(
                    video(id = 32, codecid = 7, codecs = "avc1.640033", bw = 100, base = "avc"),
                ),
            ),
        ).toDomain()

        assertEquals(listOf(32), playUrl.qualities.map { it.qn })
        assertEquals(32, playUrl.defaultQn)
        assertTrue(playUrl.qualities.single().label == "480P")
    }

    private fun video(
        id: Int,
        codecid: Int,
        codecs: String,
        bw: Long,
        base: String,
        backup: List<String> = emptyList(),
    ) = DashStreamDto(
        id = id,
        baseUrl = base,
        backupUrl = backup,
        bandwidth = bw,
        codecid = codecid,
        codecs = codecs,
        width = 1920,
        height = 1080,
    )

    private fun audio(
        id: Int,
        base: String,
        backup: List<String> = emptyList(),
    ) = DashStreamDto(
        id = id,
        baseUrl = base,
        backupUrl = backup,
        bandwidth = 128,
        codecid = 0,
        codecs = "mp4a.40.2",
    )
}
