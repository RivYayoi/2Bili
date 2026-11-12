package tv.bili.data.mapper

import tv.bili.data.api.BiliHeaders
import tv.bili.data.dto.DashStreamDto
import tv.bili.data.dto.PlayUrlDto
import tv.bili.domain.model.PlayUrl
import tv.bili.domain.model.VideoQuality
import tv.bili.domain.player.PlaySource

internal fun PlayUrlDto.toDomain(): PlayUrl {
    val headers = mapOf(
        "Referer" to BiliHeaders.REFERER,
        "User-Agent" to BiliHeaders.UA,
    )

    val sources = mutableMapOf<Int, PlaySource>()

    dash?.let { dash ->
        // Prefer standard AAC audio (30216..30280); Dolby/FLAC streams are not
        // guaranteed to decode on every desktop VLC build. Keep every AAC
        // variant as a fallback: the primary URL of one bitrate may be on an
        // unreachable MCDN host while another variant still works.
        val audioStreams = dash.audio
            .filter { it.id in 30216..30280 }
            .sortedWith(compareBy({ audioPriority(it.id) }, { -it.bandwidth }))
            .ifEmpty { dash.audio.sortedByDescending { it.bandwidth } }

        // Bilibili's primary audio URL is often the P2P/MCDN host, which can be
        // unreachable from some networks (TLS handshake timeout). Sort across
        // *all* audio variants by host, not per-variant: the preferred 132 kbps
        // variant may only have an MCDN URL while another variant has a
        // reachable upos mirror. A failed :input-slave also tears down the
        // video output in VLC 3, so this ordering is important for playback.
        val audioUrls = audioStreams
            .flatMap { stream ->
                stream.orderedUrls(preferDirect = true).map { url -> url to stream.id }
            }
            .filter { (url, _) -> url.isNotBlank() }
            .sortedWith(
                compareBy(
                    { (url, _) -> audioHostPriority(url) },
                    { (_, id) -> audioPriority(id) },
                ),
            )
            .map { (url, _) -> url }
            .distinct()

        dash.video.groupBy { it.id }.forEach { (qn, streams) ->
            val video = streams.pickVideo() ?: return@forEach
            // AVC's primary URL is usually the reachable MCDN edge; for HEVC/AV1
            // the primary is frequently an MCDN host that fails its TLS
            // handshake, so try the upos mirror first and avoid an 8 s black
            // screen before the watchdog rotates to it.
            val videoUrls = video.orderedUrls(preferDirect = video.codecid != 7)
            if (videoUrls.isEmpty()) return@forEach

            sources[qn] = PlaySource(
                videoUrl = videoUrls.first(),
                audioUrl = audioUrls.firstOrNull(),
                headers = headers,
                isDash = true,
                backupVideoUrls = videoUrls.drop(1),
                backupAudioUrls = audioUrls.drop(1),
            )
        }
    }

    val progressive = durl.firstOrNull()?.url?.takeIf { it.isNotBlank() }
    if (sources.isEmpty() && progressive != null) {
        sources[quality] = PlaySource(
            videoUrl = progressive,
            headers = headers,
            isDash = false,
        )
    }

    val qualities = buildList {
        if (acceptQuality.isNotEmpty()) {
            acceptQuality.forEachIndexed { index, qn ->
                add(VideoQuality(qn, acceptDescription.getOrElse(index) { qualityLabel(qn) }))
            }
        } else {
            sources.keys.sortedDescending().forEach { add(VideoQuality(it, qualityLabel(it))) }
        }
    }.filter { sources.containsKey(it.qn) }

    val defaultQn = qualities.firstOrNull()?.qn
        ?: sources.keys.maxOrNull()
        ?: quality

    return PlayUrl(
        qualities = qualities,
        sources = sources,
        defaultQn = defaultQn,
    )
}

/**
 * Pick the most compatible codec for the desktop player.
 *
 * Bilibili returns AVC, HEVC and AV1 variants for the same quality. VLC 3.x
 * decodes all three, but AVC is the least demanding and is also the variant
 * whose primary CDN URL is most consistently reachable. Dolby Vision (dvh1/
 * dvhe) is deliberately skipped: VLC falls back to a black/green image for it.
 */
private fun List<DashStreamDto>.pickVideo(): DashStreamDto? {
    val sdr = filterNot { it.isDolbyVision() }
    val candidates = sdr.filter { it.codecid == 7 }
        .ifEmpty { sdr.filter { it.codecid == 12 } }
        .ifEmpty { sdr.filter { it.codecid == 13 } }
        .ifEmpty { sdr }
        .ifEmpty { this }
    return candidates.maxByOrNull { it.bandwidth }
}

private fun DashStreamDto.isDolbyVision(): Boolean {
    val codec = codecs?.lowercase().orEmpty()
    return codec.startsWith("dvh") ||
        codec.startsWith("dvhe") ||
        codec.startsWith("dvav") ||
        codec.startsWith("dovi")
}

private fun audioPriority(id: Int): Int = when (id) {
    30232 -> 0 // 132 kbps AAC-LC: the most widely compatible variant
    30280 -> 1 // 192 kbps AAC-LC
    30216 -> 2 // 64 kbps AAC-LC
    else -> 3
}

/**
 * Host reachability heuristic for audio.
 *
 * The MCDN hosts (`*.mcdn.bilivideo.cn`) are frequently unreachable because
 * their TLS handshake times out, and VLC 3 destroys the whole video output
 * when an `:input-slave` fails. Prefer the direct upos/bilivideo mirrors.
 */
private fun audioHostPriority(url: String): Int = when {
    url.contains("upos-sz", ignoreCase = true) -> 0
    url.contains("bilivideo.com", ignoreCase = true) -> 1
    url.contains("mountaintoys", ignoreCase = true) -> 2
    url.contains("mcdn.bilivideo.cn", ignoreCase = true) -> 3
    else -> 2
}

private fun DashStreamDto.orderedUrls(preferDirect: Boolean): List<String> {
    val direct = backupUrl.filter { it.contains("upos-sz", ignoreCase = true) }
    val ordered = if (preferDirect) {
        direct + listOf(baseUrl) + backupUrl
    } else {
        listOf(baseUrl) + direct + backupUrl
    }
    return ordered.filter { it.isNotBlank() }.distinct()
}

private fun qualityLabel(qn: Int): String = when (qn) {
    127 -> "8K"
    126 -> "杜比视界"
    125 -> "HDR"
    120 -> "4K"
    116 -> "1080P60"
    112 -> "1080P+"
    80 -> "1080P"
    74 -> "720P60"
    64 -> "720P"
    32 -> "480P"
    16 -> "360P"
    else -> "${qn}P"
}
