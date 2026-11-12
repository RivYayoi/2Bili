package tv.bili.domain.model

data class VideoDetail(
    val bvid: String,
    val aid: Long,
    val title: String,
    val coverUrl: String,
    val description: String,
    val durationSec: Int,
    val ownerName: String,
    val ownerFaceUrl: String,
    val viewCount: Long,
    val danmakuCount: Long,
    val pages: List<VideoPage>,
)

data class VideoPage(
    val cid: Long,
    val page: Int,
    val title: String,
    val durationSec: Int,
)
