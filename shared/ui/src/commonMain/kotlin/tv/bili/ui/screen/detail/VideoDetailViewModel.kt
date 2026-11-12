package tv.bili.ui.screen.detail

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
import tv.bili.domain.model.VideoDetail
import tv.bili.domain.repository.VideoRepository

data class VideoDetailUiState(
    val detail: VideoDetail? = null,
    val isLoading: Boolean = true,
    val error: AppError? = null,
)

class VideoDetailViewModel(
    private val repository: VideoRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(VideoDetailUiState())
    val state: StateFlow<VideoDetailUiState> = _state.asStateFlow()

    private var currentBvid: String? = null
    private var job: Job? = null

    fun load(bvid: String, force: Boolean = false) {
        if (!force && currentBvid == bvid && _state.value.detail != null) return
        currentBvid = bvid
        job?.cancel()

        job = viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }

            when (val result = repository.detail(bvid)) {
                is AppResult.Success -> _state.update {
                    it.copy(detail = result.value, isLoading = false, error = null)
                }

                is AppResult.Failure -> _state.update {
                    it.copy(isLoading = false, error = result.error)
                }
            }
        }
    }

    fun retry() {
        currentBvid?.let { load(it, force = true) }
    }
}
