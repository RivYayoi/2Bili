package tv.bili.domain.model

data class Video(
    val bvid: String,
    val aid: Long = 0L,
    val title: String,
    val coverUrl: String,
    val durationSec: Int = 0,
    val ownerName: String = "",
    val viewCount: Long = 0L,
    val danmakuCount: Long = 0L,
)
