package tv.bili.ui.screen.home

import tv.bili.core.error.AppError
import tv.bili.domain.model.Video

data class HomeUiState(
    val items: List<Video> = emptyList(),
    val isInitialLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = true,
    val initialError: AppError? = null,
    val loadMoreError: AppError? = null,
) {
    val isEmpty: Boolean
        get() = items.isEmpty() && !isInitialLoading && initialError == null
}
