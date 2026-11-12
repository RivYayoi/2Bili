package tv.bili.domain.player

/**
 * Everything the player needs to start playback.
 * Produced by the data layer so that UI never has to know about Referer / UA headers.
 */
data class PlaySource(
    val videoUrl: String,
    val audioUrl: String? = null,
    val headers: Map<String, String> = emptyMap(),
    val startPositionMs: Long = 0L,
    val isDash: Boolean = false,
    /** Alternative CDN URLs, tried when the primary video stream fails. */
    val backupVideoUrls: List<String> = emptyList(),
    /** Alternative CDN URLs, tried when the primary audio stream fails. */
    val backupAudioUrls: List<String> = emptyList(),
)
