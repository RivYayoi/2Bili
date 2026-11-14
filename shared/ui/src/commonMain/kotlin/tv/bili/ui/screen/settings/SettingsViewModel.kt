package tv.bili.ui.screen.settings

import androidx.lifecycle.ViewModel
import tv.bili.ui.settings.SettingsRepository

class SettingsViewModel(
    private val repository: SettingsRepository,
) : ViewModel() {

    val state = repository.state

    fun setDefaultQuality(qn: Int) = repository.update { it.copy(defaultQuality = qn) }

    fun setDanmakuEnabled(enabled: Boolean) =
        repository.update { it.copy(danmakuEnabled = enabled) }

    fun setDanmakuOpacity(opacity: Float) =
        repository.update { it.copy(danmakuOpacity = opacity.coerceIn(0.2f, 1f)) }

    fun setDanmakuFontScale(scale: Float) =
        repository.update { it.copy(danmakuFontScale = scale.coerceIn(0.6f, 2f)) }

    fun reset() = repository.reset()
}
