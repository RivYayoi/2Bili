package tv.bili.domain.model

import tv.bili.domain.player.PlaySource

/**
 * A resolved play URL set.
 *
 * Bilibili returns DASH video/audio as *separate* streams. Both platform players
 * are able to merge them (VLC: :input-slave, Media3: MergingMediaSource), so the
 * domain exposes one PlaySource per quality instead of raw stream lists.
 */
data class PlayUrl(
    val qualities: List<VideoQuality>,
    val sources: Map<Int, PlaySource>,
    val defaultQn: Int,
) {
    fun source(qn: Int): PlaySource? = sources[qn] ?: sources[defaultQn] ?: sources.values.firstOrNull()
}

data class VideoQuality(
    val qn: Int,
    val label: String,
)
