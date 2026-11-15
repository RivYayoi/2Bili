package tv.bili.data.mapper

import tv.bili.data.dto.ReplyDto
import tv.bili.domain.model.VideoComment

internal fun ReplyDto.toComment(upperMid: Long): VideoComment {
    val memberMid = member?.mid?.toLongOrNull() ?: mid
    return VideoComment(
        rpid = rpid,
        mid = memberMid,
        userName = member?.uname.orEmpty().ifBlank { "匿名用户" },
        avatarUrl = member?.avatar.orEmpty().normalizeBiliUrl(),
        message = content?.message.orEmpty(),
        likeCount = like,
        createdAt = ctime,
        replyCount = rcount,
        isUploader = upperMid > 0L && memberMid == upperMid,
        replies = replies.map { it.toComment(upperMid) },
    )
}
