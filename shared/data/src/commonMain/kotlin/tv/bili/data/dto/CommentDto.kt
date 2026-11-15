package tv.bili.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ReplyMainDto(
    val cursor: ReplyCursorDto? = null,
    val replies: List<ReplyDto> = emptyList(),
    @SerialName("top_replies") val topReplies: List<ReplyDto> = emptyList(),
    val upper: ReplyUpperDto? = null,
    val page: ReplyPageDto? = null,
)

@Serializable
data class ReplyCursorDto(
    @SerialName("is_end") val isEnd: Boolean = true,
    @SerialName("all_count") val allCount: Long = 0L,
    @SerialName("pagination_reply") val paginationReply: ReplyPaginationDto? = null,
    val mode: Int = 0,
)

@Serializable
data class ReplyPaginationDto(
    @SerialName("next_offset") val nextOffset: String = "",
)

@Serializable
data class ReplyPaginationRequest(
    val offset: String,
)

@Serializable
data class ReplyPageDto(
    val count: Long = 0L,
    val num: Int = 0,
    val size: Int = 20,
)

@Serializable
data class ReplyUpperDto(
    val mid: Long = 0L,
)

@Serializable
data class ReplyDto(
    val rpid: Long = 0L,
    val oid: Long = 0L,
    val mid: Long = 0L,
    val root: Long = 0L,
    val parent: Long = 0L,
    val ctime: Long = 0L,
    val like: Long = 0L,
    val rcount: Int = 0,
    val member: ReplyMemberDto? = null,
    val content: ReplyContentDto? = null,
    val replies: List<ReplyDto> = emptyList(),
)

@Serializable
data class ReplyMemberDto(
    val mid: String = "",
    val uname: String = "",
    val avatar: String = "",
)

@Serializable
data class ReplyContentDto(
    val message: String = "",
)
