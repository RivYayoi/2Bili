package tv.bili.ui.screen.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import tv.bili.core.error.AppError
import tv.bili.core.result.AppResult
import tv.bili.domain.model.Video
import tv.bili.domain.repository.SearchRepository

data class SearchUiState(
    val query: String = "",
    val items: List<Video> = emptyList(),
    val isSearching: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = false,
    val error: AppError? = null,
    val hasSearched: Boolean = false,
)

class SearchViewModel(
    private val repository: SearchRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(SearchUiState())
    val state: StateFlow<SearchUiState> = _state.asStateFlow()

    private var nextPage: Int = 1
    private var currentQuery: String = ""
    private var job: Job? = null

    fun onQueryChange(value: String) {
        _state.update { it.copy(query = value) }
    }

    fun search() {
        val query = _state.value.query.trim()
        if (query.isEmpty()) return

        currentQuery = query
        nextPage = 1
        job?.cancel()

        job = viewModelScope.launch {
            _state.update {
                it.copy(
                    isSearching = true,
                    isLoadingMore = false,
                    error = null,
                    hasSearched = true,
                    items = emptyList(),
                    hasMore = false,
                )
            }

            when (val result = repository.search(query, page = 1, pageSize = PAGE_SIZE)) {
                is AppResult.Success -> {
                    nextPage = 2
                    _state.update {
                        it.copy(
                            items = result.value.items,
                            isSearching = false,
                            hasMore = result.value.hasMore,
                        )
                    }
                }

                is AppResult.Failure -> _state.update {
                    it.copy(isSearching = false, error = result.error)
                }
            }
        }
    }

    fun loadMore() {
        val snapshot = _state.value
        if (snapshot.isSearching || snapshot.isLoadingMore) return
        if (!snapshot.hasMore || snapshot.error != null) return
        if (currentQuery.isBlank()) return

        job = viewModelScope.launch {
            _state.update { it.copy(isLoadingMore = true) }

            when (val result = repository.search(currentQuery, page = nextPage, pageSize = PAGE_SIZE)) {
                is AppResult.Success -> {
                    nextPage += 1
                    _state.update { current ->
                        current.copy(
                            items = (current.items + result.value.items).distinctBy { it.bvid },
                            isLoadingMore = false,
                            hasMore = result.value.hasMore,
                        )
                    }
                }

                is AppResult.Failure -> _state.update {
                    it.copy(isLoadingMore = false, error = result.error)
                }
            }
        }
    }

    fun retry() {
        if (currentQuery.isNotBlank()) search()
    }

    private companion object {
        const val PAGE_SIZE = 20
    }
}
