package tv.bili.ui.screen.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import tv.bili.core.error.AppError
import tv.bili.core.error.toUserMessage
import tv.bili.core.format.formatCommentTime
import tv.bili.core.format.formatCount
import tv.bili.domain.model.CommentSort
import tv.bili.domain.model.VideoComment

@Composable
fun CommentHeader(
    totalCount: Long,
    sort: CommentSort,
    onSortChange: (CommentSort) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = if (totalCount > 0L) "评论 ${formatCount(totalCount)}" else "评论",
                style = MaterialTheme.typography.titleMedium,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SortChip(
                    label = "热门",
                    selected = sort == CommentSort.Hot,
                    onClick = { onSortChange(CommentSort.Hot) },
                )
                SortChip(
                    label = "最新",
                    selected = sort == CommentSort.Latest,
                    onClick = { onSortChange(CommentSort.Latest) },
                )
            }
        }
        HorizontalDivider()
    }
}

@Composable
fun CommentCard(
    comment: VideoComment,
    expandedReplies: List<VideoComment>?,
    isLoadingReplies: Boolean,
    replyError: AppError?,
    replyHasMore: Boolean,
    onLoadReplies: () -> Unit,
) {
    var messageExpanded by remember(comment.rpid) { mutableStateOf(false) }
    val replies = expandedReplies ?: comment.replies
    val expanded = expandedReplies != null
    val canExpandMessage = comment.message.length > 220 || comment.message.count { it == '\n' } > 6
    val hasMoreReplies = replyHasMore || (!expanded && comment.replyCount > replies.size)

    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            UserAvatar(
                url = comment.avatarUrl,
                name = comment.userName,
                size = 40.dp,
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = comment.userName,
                        modifier = Modifier.weight(1f, fill = false),
                        style = MaterialTheme.typography.labelLarge,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (comment.isUploader) {
                        UpBadge()
                    }
                    Text(
                        text = formatCommentTime(comment.createdAt),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    text = comment.message.ifBlank { " " },
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = if (messageExpanded) Int.MAX_VALUE else 8,
                    overflow = TextOverflow.Ellipsis,
                )
                if (canExpandMessage) {
                    TextButton(
                        onClick = { messageExpanded = !messageExpanded },
                        contentPadding = PaddingValues(0.dp),
                    ) {
                        Text(if (messageExpanded) "收起" else "展开")
                    }
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        text = "赞 ${formatCount(comment.likeCount)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    if (comment.replyCount > 0) {
                        if (hasMoreReplies) {
                            TextButton(
                                onClick = onLoadReplies,
                                enabled = !isLoadingReplies,
                                contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp),
                            ) {
                                Text(
                                    text = if (expanded) {
                                        "加载更多回复"
                                    } else {
                                        "查看全部 ${comment.replyCount} 条回复"
                                    },
                                    style = MaterialTheme.typography.labelSmall,
                                )
                            }
                        } else {
                            Text(
                                text = "${comment.replyCount} 条回复",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
                if (replies.isNotEmpty()) {
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(top = 2.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        replies.forEach { reply ->
                            ReplyRow(reply = reply)
                        }
                    }
                }
                if (isLoadingReplies) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(14.dp),
                            strokeWidth = 2.dp,
                        )
                        Text(
                            text = "正在加载回复...",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                if (replyError != null) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = replyError.toUserMessage(),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                        TextButton(onClick = onLoadReplies) { Text("重试") }
                    }
                }
            }
        }
        HorizontalDivider(modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
fun CommentLoadingRow() {
    Box(
        modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(24.dp),
            strokeWidth = 2.dp,
        )
    }
}

@Composable
fun CommentEmptyRow() {
    Box(
        modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "暂无评论",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
fun CommentErrorRow(
    error: AppError,
    onRetry: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = error.toUserMessage(),
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
        )
        Button(onClick = onRetry) { Text("重试") }
    }
}

@Composable
private fun SortChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val background = if (selected) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }
    val contentColor = if (selected) {
        MaterialTheme.colorScheme.onPrimary
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(background)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 6.dp),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = contentColor,
        )
    }
}

@Composable
private fun ReplyRow(reply: VideoComment) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        UserAvatar(
            url = reply.avatarUrl,
            name = reply.userName,
            size = 28.dp,
        )
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = reply.userName,
                    modifier = Modifier.weight(1f, fill = false),
                    style = MaterialTheme.typography.labelMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (reply.isUploader) {
                    UpBadge()
                }
                Text(
                    text = formatCommentTime(reply.createdAt),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = reply.message.ifBlank { " " },
                style = MaterialTheme.typography.bodySmall,
            )
            if (reply.likeCount > 0L) {
                Text(
                    text = "赞 ${formatCount(reply.likeCount)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun UserAvatar(
    url: String,
    name: String,
    size: Dp,
) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceVariant),
        contentAlignment = Alignment.Center,
    ) {
        if (url.isNotBlank()) {
            AsyncImage(
                model = url,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            Text(
                text = name.take(1).ifBlank { "?" },
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun UpBadge() {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
            .padding(horizontal = 5.dp, vertical = 1.dp),
    ) {
        Text(
            text = "UP",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}
