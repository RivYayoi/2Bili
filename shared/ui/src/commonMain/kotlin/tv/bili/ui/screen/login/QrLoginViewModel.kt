package tv.bili.ui.screen.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import tv.bili.core.error.AppError
import tv.bili.core.result.AppResult
import tv.bili.domain.model.QrPoll
import tv.bili.domain.model.QrStatus
import tv.bili.domain.repository.AuthRepository

data class QrLoginUiState(
    val qrUrl: String? = null,
    val status: QrStatus = QrStatus.Waiting,
    val message: String = "正在获取二维码…",
    val isLoading: Boolean = true,
    val error: AppError? = null,
    val loggedIn: Boolean = false,
)

class QrLoginViewModel(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(QrLoginUiState())
    val state: StateFlow<QrLoginUiState> = _state.asStateFlow()

    private var job: Job? = null

    fun start() {
        if (job?.isActive == true) return

        job = viewModelScope.launch {
            _state.update {
                it.copy(
                    isLoading = true,
                    error = null,
                    status = QrStatus.Waiting,
                    message = "正在获取二维码…",
                )
            }

            when (val result = authRepository.generateQr()) {
                is AppResult.Success -> {
                    _state.update {
                        it.copy(
                            isLoading = false,
                            qrUrl = result.value.url,
                            message = "请使用哔哩哔哩客户端扫码",
                        )
                    }
                    poll(result.value.key)
                }

                is AppResult.Failure -> _state.update {
                    it.copy(
                        isLoading = false,
                        error = result.error,
                        message = "二维码获取失败",
                    )
                }
            }
        }
    }

    fun refresh() {
        job?.cancel()
        job = null
        _state.value = QrLoginUiState()
        start()
    }

    private suspend fun poll(key: String) {
        while (currentCoroutineContext().isActive) {
            delay(POLL_INTERVAL_MS)

            when (val result = authRepository.pollQr(key)) {
                is AppResult.Success -> {
                    val poll = result.value
                    _state.update {
                        it.copy(
                            status = poll.status,
                            message = messageFor(poll),
                            error = null,
                        )
                    }

                    when (poll.status) {
                        QrStatus.Success -> {
                            _state.update { it.copy(loggedIn = true) }
                            return
                        }

                        QrStatus.Expired -> return
                        else -> Unit
                    }
                }

                is AppResult.Failure -> _state.update { it.copy(error = result.error) }
            }
        }
    }

    private fun messageFor(poll: QrPoll): String = when (poll.status) {
        QrStatus.Waiting -> "等待扫码…"
        QrStatus.Scanned -> "已扫码，请在手机上确认"
        QrStatus.Expired -> "二维码已过期，请刷新"
        QrStatus.Success -> "登录成功"
    }

    private companion object {
        const val POLL_INTERVAL_MS = 2_000L
    }
}
