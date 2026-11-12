package tv.bili.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class SearchData(
    val page: Int = 1,
    @SerialName("numResults") val numResults: Int = 0,
    val result: List<SearchItemDto> = emptyList(),
)

@Serializable
data class SearchItemDto(
    val bvid: String = "",
    val title: String = "",
    val pic: String = "",
    val author: String = "",
    val duration: String = "",
    val play: Long = 0L,
    val danmaku: Long = 0L,
    val pubdate: Long = 0L,
)
