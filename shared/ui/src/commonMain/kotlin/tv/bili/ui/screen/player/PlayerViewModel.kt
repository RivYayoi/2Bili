package tv.bili.ui.screen.player

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import tv.bili.core.error.AppError
import tv.bili.core.result.AppResult
import tv.bili.domain.model.Danmaku
import tv.bili.domain.model.PlayUrl
import tv.bili.domain.repository.DanmakuRepository
import tv.bili.domain.repository.VideoRepository
import tv.bili.ui.settings.AppSettings
import tv.bili.ui.settings.SettingsRepository

data class PlayerUiState(
    val isLoading: Boolean = true,
    val playUrl: PlayUrl? = null,
    val selectedQn: Int = 0,
    val error: AppError? = null,
)

class PlayerViewModel(
    private val videoRepository: VideoRepository,
    private val danmakuRepository: DanmakuRepository,
    private val settingsRepository: SettingsRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(PlayerUiState())
    val state: StateFlow<PlayerUiState> = _state.asStateFlow()

    val settings: StateFlow<AppSettings> = settingsRepository.state

    private val _danmaku = MutableSharedFlow<Danmaku>(
        replay = 4_096,
        extraBufferCapacity = 64,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val danmaku: SharedFlow<Danmaku> = _danmaku.asSharedFlow()

    private var bvid: String = ""
    private var cid: Long = 0L
    private var playJob: Job? = null
    private var danmakuJob: Job? = null
    private var liveJob: Job? = null

    fun load(bvid: String, cid: Long, force: Boolean = false) {
        if (!force && this.bvid == bvid && this.cid == cid && _state.value.playUrl != null) return

        this.bvid = bvid
        this.cid = cid

        playJob?.cancel()
        danmakuJob?.cancel()
        liveJob?.cancel()

        playJob = viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null, playUrl = null) }

            val requestedQn = settingsRepository.current.defaultQuality
                .takeIf { it > 0 }
                ?: INITIAL_QN
            when (val result = videoRepository.playUrl(bvid, cid, requestedQn)) {
                is AppResult.Success -> {
                    val playUrl = result.value
                    val preferredQn = settingsRepository.current.defaultQuality
                    val selectedQn = preferredQn.takeIf { playUrl.sources.containsKey(it) }
                        ?: playUrl.defaultQn
                    _state.update {
                        it.copy(
                            isLoading = false,
                            playUrl = playUrl,
                            selectedQn = selectedQn,
                            error = null,
                        )
                    }
                }

                is AppResult.Failure -> _state.update {
                    it.copy(isLoading = false, error = result.error)
                }
            }
        }

        // Historical danmaku first, then the realtime socket. Both are funnelled
        // into one SharedFlow so the overlay only has a single source.
        danmakuJob = viewModelScope.launch {
            danmakuRepository.history(cid).getOrNull()?.forEach { _danmaku.emit(it) }
        }
        liveJob = viewModelScope.launch {
            // A broken danmaku socket must never take down the player scope.
            runCatching {
                danmakuRepository.live(cid).collect { _danmaku.emit(it) }
            }
        }
    }

    fun selectQuality(qn: Int) {
        _state.update { it.copy(selectedQn = qn) }
    }

    fun retry() {
        if (bvid.isNotBlank()) load(bvid, cid, force = true)
    }

    private companion object {
        /** 64 = 720P. Low enough to work anonymously, high enough to look decent. */
        const val INITIAL_QN = 64
    }
}
