package tv.bili.ui.screen.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.compose.viewmodel.koinViewModel
import tv.bili.domain.model.Video
import tv.bili.ui.component.EmptyView
import tv.bili.ui.component.ErrorView
import tv.bili.ui.component.LoadMoreFooter
import tv.bili.ui.component.LoadingState
import tv.bili.ui.component.VideoCard

@Composable
fun HomeScreen(
    onVideoClick: (String) -> Unit,
    onSearchClick: () -> Unit,
    onLoginClick: () -> Unit,
    onSettingsClick: () -> Unit,
    viewModel: HomeViewModel = koinViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    HomeContent(
        state = state,
        onVideoClick = onVideoClick,
        onSearchClick = onSearchClick,
        onLoginClick = onLoginClick,
        onSettingsClick = onSettingsClick,
        onRetry = viewModel::loadFirstPage,
        onLoadMore = viewModel::loadMore,
        onRetryLoadMore = viewModel::retryLoadMore,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeContent(
    state: HomeUiState,
    onVideoClick: (String) -> Unit,
    onSearchClick: () -> Unit,
    onLoginClick: () -> Unit,
    onSettingsClick: () -> Unit,
    onRetry: () -> Unit,
    onLoadMore: () -> Unit,
    onRetryLoadMore: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("推荐") },
                actions = {
                    IconButton(onClick = onSearchClick) {
                        Icon(Icons.Default.Search, contentDescription = "搜索")
                    }
                    IconButton(onClick = onSettingsClick) {
                        Icon(Icons.Default.Settings, contentDescription = "设置")
                    }
                    IconButton(onClick = onLoginClick) {
                        Icon(Icons.Default.AccountCircle, contentDescription = "登录")
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
                state.isInitialLoading -> LoadingState(Modifier.fillMaxSize())

                state.initialError != null -> ErrorView(
                    error = state.initialError,
                    onRetry = onRetry,
                    modifier = Modifier.fillMaxSize(),
                )

                state.isEmpty -> EmptyView(
                    message = "还没有推荐内容",
                    onAction = onRetry,
                    modifier = Modifier.fillMaxSize(),
                )

                else -> VideoGrid(
                    state = state,
                    onVideoClick = onVideoClick,
                    onLoadMore = onLoadMore,
                    onRetryLoadMore = onRetryLoadMore,
                )
            }
        }
    }
}

@Composable
private fun VideoGrid(
    state: HomeUiState,
    onVideoClick: (String) -> Unit,
    onLoadMore: () -> Unit,
    onRetryLoadMore: () -> Unit,
) {
    val gridState = rememberLazyGridState()
    val itemCount = state.items.size

    // Prefetch when the last visible card is within 6 items of the end.
    val shouldLoadMore by remember(itemCount, state.hasMore, state.loadMoreError) {
        derivedStateOf {
            if (!state.hasMore || state.loadMoreError != null) return@derivedStateOf false
            val lastVisible = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1
            lastVisible >= itemCount - 6
        }
    }

    LaunchedEffect(shouldLoadMore) {
        if (shouldLoadMore) onLoadMore()
    }

    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 220.dp),
        state = gridState,
        modifier = Modifier
            .widthIn(max = 1600.dp)
            .fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        itemsIndexed(
            items = state.items,
            // The recommend feed occasionally contains cards without a bvid;
            // including the index keeps keys unique even then.
            key = { index, video -> "${video.bvid}#$index" },
        ) { _, video: Video ->
            VideoCard(
                video = video,
                onClick = { onVideoClick(video.bvid) },
            )
        }

        item(span = { GridItemSpan(maxLineSpan) }) {
            LoadMoreFooter(
                isLoading = state.isLoadingMore,
                error = state.loadMoreError,
                hasMore = state.hasMore,
                onRetry = onRetryLoadMore,
            )
        }
    }
}
