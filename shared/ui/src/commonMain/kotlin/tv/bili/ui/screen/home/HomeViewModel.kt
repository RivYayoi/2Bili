package tv.bili.ui.screen.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import tv.bili.core.result.AppResult
import tv.bili.domain.repository.VideoRepository

class HomeViewModel(
    private val repository: VideoRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(HomeUiState())
    val state: StateFlow<HomeUiState> = _state.asStateFlow()

    private var nextPage: Int = 1
    private var loadJob: Job? = null

    init {
        loadFirstPage()
    }

    fun loadFirstPage() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            _state.update {
                it.copy(
                    isInitialLoading = it.items.isEmpty(),
                    isRefreshing = it.items.isNotEmpty(),
                    initialError = null,
                    loadMoreError = null,
                )
            }

            when (val result = repository.recommend(page = 1, pageSize = PAGE_SIZE)) {
                is AppResult.Success -> {
                    nextPage = 2
                    _state.update {
                        it.copy(
                            items = result.value.items,
                            isInitialLoading = false,
                            isRefreshing = false,
                            hasMore = result.value.hasMore,
                            initialError = null,
                            loadMoreError = null,
                        )
                    }
                }

                is AppResult.Failure -> {
                    _state.update {
                        it.copy(
                            isInitialLoading = false,
                            isRefreshing = false,
                            initialError = if (it.items.isEmpty()) result.error else null,
                            loadMoreError = if (it.items.isEmpty()) null else result.error,
                        )
                    }
                }
            }
        }
    }

    fun loadMore() {
        val snapshot = _state.value
        if (snapshot.isInitialLoading || snapshot.isRefreshing) return
        if (snapshot.isLoadingMore || !snapshot.hasMore) return
        if (snapshot.loadMoreError != null) return
        if (loadJob?.isActive == true) return

        loadJob = viewModelScope.launch {
            _state.update { it.copy(isLoadingMore = true) }

            when (val result = repository.recommend(page = nextPage, pageSize = PAGE_SIZE)) {
                is AppResult.Success -> {
                    nextPage += 1
                    _state.update { current ->
                        current.copy(
                            items = (current.items + result.value.items).distinctBy { it.bvid },
                            isLoadingMore = false,
                            hasMore = result.value.hasMore,
                            loadMoreError = null,
                        )
                    }
                }

                is AppResult.Failure -> {
                    _state.update {
                        it.copy(isLoadingMore = false, loadMoreError = result.error)
                    }
                }
            }
        }
    }

    fun retryLoadMore() {
        _state.update { it.copy(loadMoreError = null) }
        loadMore()
    }

    private companion object {
        const val PAGE_SIZE = 20
    }
}
