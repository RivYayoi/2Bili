package tv.bili.ui.screen.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import org.koin.compose.viewmodel.koinViewModel
import tv.bili.core.format.formatCount
import tv.bili.core.format.formatDuration
import tv.bili.domain.model.CommentSort
import tv.bili.domain.model.VideoDetail
import tv.bili.domain.model.VideoPage
import tv.bili.ui.component.ErrorView
import tv.bili.ui.component.LoadMoreFooter
import tv.bili.ui.component.LoadingState

@Composable
fun VideoDetailScreen(
    bvid: String,
    onBack: () -> Unit,
    onPlay: (cid: Long, title: String) -> Unit,
    viewModel: VideoDetailViewModel = koinViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(bvid) {
        viewModel.load(bvid)
    }

    DetailContent(
        state = state,
        onBack = onBack,
        onRetry = viewModel::retry,
        onPlay = onPlay,
        onCommentSortChange = viewModel::setCommentSort,
        onRetryComments = viewModel::retryComments,
        onLoadMoreComments = viewModel::loadMoreComments,
        onLoadReplies = viewModel::loadReplies,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DetailContent(
    state: VideoDetailUiState,
    onBack: () -> Unit,
    onRetry: () -> Unit,
    onPlay: (cid: Long, title: String) -> Unit,
    onCommentSortChange: (CommentSort) -> Unit,
    onRetryComments: () -> Unit,
    onLoadMoreComments: () -> Unit,
    onLoadReplies: (Long) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.detail?.title ?: "视频详情", maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentAlignment = Alignment.TopCenter,
        ) {
            when {
                state.isLoading && state.detail == null -> LoadingState(Modifier.fillMaxSize())

                state.error != null && state.detail == null -> ErrorView(
                    error = state.error,
                    onRetry = onRetry,
                    modifier = Modifier.fillMaxSize(),
                )

                state.detail != null -> DetailBody(
                    detail = state.detail,
                    comments = state.comments,
                    onPlay = onPlay,
                    onCommentSortChange = onCommentSortChange,
                    onRetryComments = onRetryComments,
                    onLoadMoreComments = onLoadMoreComments,
                    onLoadReplies = onLoadReplies,
                )
            }
        }
    }
}

@Composable
private fun DetailBody(
    detail: VideoDetail,
    comments: CommentsUiState,
    onPlay: (cid: Long, title: String) -> Unit,
    onCommentSortChange: (CommentSort) -> Unit,
    onRetryComments: () -> Unit,
    onLoadMoreComments: () -> Unit,
    onLoadReplies: (Long) -> Unit,
) {
    BoxWithConstraints(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.TopCenter,
    ) {
        // Desktop gets a two-column header so the cover, title, play button and
        // description all fit above the fold even at the 800x600 minimum size.
        val wide = maxWidth >= 720.dp
        val listState = rememberLazyListState()

        val shouldLoadMore by remember {
            derivedStateOf {
                val layoutInfo = listState.layoutInfo
                val lastVisible = layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1
                lastVisible >= layoutInfo.totalItemsCount - 3
            }
        }

        LaunchedEffect(
            shouldLoadMore,
            comments.hasMore,
            comments.isLoading,
            comments.isLoadingMore,
        ) {
            if (shouldLoadMore &&
                comments.items.isNotEmpty() &&
                comments.hasMore &&
                !comments.isLoading &&
                !comments.isLoadingMore
            ) {
                onLoadMoreComments()
            }
        }

        LazyColumn(
            state = listState,
            modifier = Modifier
                .widthIn(max = 1100.dp)
                .fillMaxSize(),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                if (wide) {
                    WideDetailHeader(detail = detail, onPlay = onPlay)
                } else {
                    StackedDetailHeader(detail = detail, onPlay = onPlay)
                }
            }

            if (detail.pages.size > 1) {
                item {
                    Text("分P（${detail.pages.size}）", style = MaterialTheme.typography.titleMedium)
                }

                items(
                    items = detail.pages,
                    key = { it.cid },
                ) { page: VideoPage ->
                    PageRow(page = page, onClick = { onPlay(page.cid, page.title) })
                }
            }

            item(key = "comments-header") {
                CommentHeader(
                    totalCount = comments.totalCount,
                    sort = comments.sort,
                    onSortChange = onCommentSortChange,
                )
            }

            when {
                comments.isLoading && comments.items.isEmpty() -> {
                    item(key = "comments-loading") {
                        CommentLoadingRow()
                    }
                }

                comments.error != null && comments.items.isEmpty() -> {
                    item(key = "comments-error") {
                        CommentErrorRow(
                            error = comments.error,
                            onRetry = onRetryComments,
                        )
                    }
                }

                comments.items.isEmpty() -> {
                    item(key = "comments-empty") {
                        CommentEmptyRow()
                    }
                }

                else -> {
                    items(
                        items = comments.items,
                        key = { "comment-${it.rpid}" },
                    ) { comment ->
                        CommentCard(
                            comment = comment,
                            expandedReplies = comments.expandedReplies[comment.rpid],
                            isLoadingReplies = comment.rpid in comments.loadingReplies,
                            replyError = comments.replyErrors[comment.rpid],
                            replyHasMore = comments.replyHasMore[comment.rpid] == true,
                            onLoadReplies = { onLoadReplies(comment.rpid) },
                        )
                    }

                    item(key = "comments-footer") {
                        LoadMoreFooter(
                            isLoading = comments.isLoadingMore,
                            error = comments.error,
                            hasMore = comments.hasMore,
                            onRetry = onRetryComments,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun WideDetailHeader(
    detail: VideoDetail,
    onPlay: (cid: Long, title: String) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(24.dp),
        verticalAlignment = Alignment.Top,
    ) {
        CoverImage(
            detail = detail,
            modifier = Modifier
                .weight(0.45f)
                .aspectRatio(16f / 9f),
        )
        Column(
            modifier = Modifier.weight(0.55f),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            DetailInfo(detail = detail, onPlay = onPlay, compact = true)
        }
    }
}

@Composable
private fun StackedDetailHeader(
    detail: VideoDetail,
    onPlay: (cid: Long, title: String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        CoverImage(
            detail = detail,
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f),
        )
        DetailInfo(detail = detail, onPlay = onPlay, compact = false)
    }
}

@Composable
private fun CoverImage(
    detail: VideoDetail,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant),
    ) {
        AsyncImage(
            model = detail.coverUrl,
            contentDescription = detail.title,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop,
        )
    }
}

@Composable
private fun DetailInfo(
    detail: VideoDetail,
    onPlay: (cid: Long, title: String) -> Unit,
    compact: Boolean,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = detail.title,
            style = MaterialTheme.typography.headlineSmall,
            maxLines = if (compact) 2 else Int.MAX_VALUE,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = buildString {
                append(detail.ownerName)
                append(" · ${formatCount(detail.viewCount)}播放")
                append(" · ${formatCount(detail.danmakuCount)}弹幕")
                append(" · ${formatDuration(detail.durationSec)}")
            },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Button(
            onClick = {
                detail.pages.firstOrNull()?.let { page ->
                    onPlay(page.cid, detail.title)
                }
            },
            enabled = detail.pages.isNotEmpty(),
        ) {
            Icon(Icons.Default.PlayArrow, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text("播放第一页")
        }
        Text(
            text = detail.description.ifBlank { "暂无简介" },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = if (compact) 5 else Int.MAX_VALUE,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun PageRow(
    page: VideoPage,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "P${page.page}",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.width(12.dp))
            Text(
                text = page.title,
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodyMedium,
            )
            Text(
                text = formatDuration(page.durationSec),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
