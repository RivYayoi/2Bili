package tv.bili.ui.screen.search

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.compose.viewmodel.koinViewModel
import tv.bili.ui.component.EmptyView
import tv.bili.ui.component.ErrorView
import tv.bili.ui.component.LoadMoreFooter
import tv.bili.ui.component.LoadingState
import tv.bili.ui.component.VideoCard

@Composable
fun SearchScreen(
    onBack: () -> Unit,
    onVideoClick: (String) -> Unit,
    viewModel: SearchViewModel = koinViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    SearchContent(
        state = state,
        onBack = onBack,
        onQueryChange = viewModel::onQueryChange,
        onSearch = viewModel::search,
        onVideoClick = onVideoClick,
        onLoadMore = viewModel::loadMore,
        onRetry = viewModel::retry,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SearchContent(
    state: SearchUiState,
    onBack: () -> Unit,
    onQueryChange: (String) -> Unit,
    onSearch: () -> Unit,
    onVideoClick: (String) -> Unit,
    onLoadMore: () -> Unit,
    onRetry: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        OutlinedTextField(
                            value = state.query,
                            onValueChange = onQueryChange,
                            modifier = Modifier.weight(1f),
                            placeholder = { Text("搜索视频") },
                            singleLine = true,
                            leadingIcon = {
                                Icon(Icons.Default.Search, contentDescription = null)
                            },
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                            keyboardActions = KeyboardActions(onSearch = { onSearch() }),
                        )
                        Button(
                            onClick = onSearch,
                            modifier = Modifier.padding(start = 8.dp),
                        ) {
                            Text("搜索")
                        }
                    }
                },
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
                state.isSearching -> LoadingState(Modifier.fillMaxSize())

                state.error != null && state.items.isEmpty() -> ErrorView(
                    error = state.error,
                    onRetry = onRetry,
                    modifier = Modifier.fillMaxSize(),
                )

                !state.hasSearched -> EmptyView(
                    message = "输入关键词开始搜索",
                    modifier = Modifier.fillMaxSize(),
                )

                state.items.isEmpty() -> EmptyView(
                    message = "没有找到相关视频",
                    modifier = Modifier.fillMaxSize(),
                )

                else -> SearchResults(
                    state = state,
                    onVideoClick = onVideoClick,
                    onLoadMore = onLoadMore,
                    onRetry = onRetry,
                )
            }
        }
    }
}

@Composable
private fun SearchResults(
    state: SearchUiState,
    onVideoClick: (String) -> Unit,
    onLoadMore: () -> Unit,
    onRetry: () -> Unit,
) {
    val gridState = rememberLazyGridState()
    val itemCount = state.items.size

    val shouldLoadMore by remember(itemCount, state.hasMore, state.isLoadingMore) {
        derivedStateOf {
            if (!state.hasMore || state.isLoadingMore) return@derivedStateOf false
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
            key = { index, video -> "${video.bvid}#$index" },
        ) { _, video ->
            VideoCard(
                video = video,
                onClick = { onVideoClick(video.bvid) },
            )
        }

        item(span = { GridItemSpan(maxLineSpan) }) {
            LoadMoreFooter(
                isLoading = state.isLoadingMore,
                error = state.error,
                hasMore = state.hasMore,
                onRetry = onRetry,
            )
        }
    }
}
