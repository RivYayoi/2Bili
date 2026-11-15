package tv.bili.domain.model

enum class CommentSort(val apiMode: Int) {
    Hot(3),
    Latest(2),
}

data class VideoComment(
    val rpid: Long,
    val mid: Long,
    val userName: String,
    val avatarUrl: String,
    val message: String,
    val likeCount: Long,
    val createdAt: Long,
    val replyCount: Int,
    val isUploader: Boolean = false,
    val replies: List<VideoComment> = emptyList(),
)

data class CommentPage(
    val items: List<VideoComment>,
    val totalCount: Long,
    val hasMore: Boolean,
    val nextOffset: String? = null,
)

data class ReplyPage(
    val items: List<VideoComment>,
    val totalCount: Long,
    val hasMore: Boolean,
    val nextPage: Int? = null,
)
