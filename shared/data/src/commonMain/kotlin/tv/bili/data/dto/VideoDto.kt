package tv.bili.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RcmdDto(
    val item: List<VideoItemDto> = emptyList(),
)

@Serializable
data class PopularDto(
    val list: List<VideoItemDto> = emptyList(),
    @SerialName("no_more") val noMore: Boolean = false,
)

@Serializable
data class VideoItemDto(
    val aid: Long = 0L,
    val bvid: String = "",
    val cid: Long = 0L,
    val title: String = "",
    val pic: String = "",
    val duration: Long = 0L,
    val pubdate: Long = 0L,
    val owner: OwnerDto? = null,
    val stat: StatDto? = null,
)

@Serializable
data class OwnerDto(
    val mid: Long = 0L,
    val name: String = "",
    val face: String = "",
)

@Serializable
data class StatDto(
    val view: Long = 0L,
    val danmaku: Long = 0L,
)

@Serializable
data class ViewDto(
    val bvid: String = "",
    val aid: Long = 0L,
    val cid: Long = 0L,
    val title: String = "",
    val pic: String = "",
    val desc: String = "",
    val duration: Long = 0L,
    val pubdate: Long = 0L,
    val owner: OwnerDto? = null,
    val stat: StatDto? = null,
    val pages: List<PageDto> = emptyList(),
)

@Serializable
data class PageDto(
    val cid: Long = 0L,
    val page: Int = 0,
    val part: String = "",
    val duration: Long = 0L,
)
