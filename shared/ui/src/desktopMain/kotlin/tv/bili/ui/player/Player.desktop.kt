package tv.bili.ui.player

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import tv.bili.domain.player.PlaySource
import tv.bili.domain.player.PlayerController
import tv.bili.domain.player.PlayerState

@Composable
actual fun rememberPlayerController(): PlayerController {
    val controller = remember {
        runCatching { VlcjPlayerController() }
            .getOrElse { FailedPlayerController("无法初始化 VLC：${it.message}") }
    }

    DisposableEffect(controller) {
        onDispose { controller.release() }
    }

    return controller
}

@Composable
actual fun PlatformVideoSurface(
    controller: PlayerController,
    modifier: Modifier,
) {
    val vlc = controller as? VlcjPlayerController
    if (vlc == null) {
        Box(modifier.background(Color.Black), contentAlignment = Alignment.Center) {
            Text("当前播放器不可用", color = Color.White)
        }
        return
    }

    val frame by vlc.frame.collectAsState()

    Box(
        modifier = modifier.background(Color.Black),
        contentAlignment = Alignment.Center,
    ) {
        frame?.let { bitmap: ImageBitmap ->
            androidx.compose.foundation.Image(
                bitmap = bitmap,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit,
            )
        }
    }
}

/**
 * Degraded controller used when VLC natives are missing, so the rest of the UI
 * (danmaku, controls, navigation) still works and the error is visible.
 */
private class FailedPlayerController(message: String) : PlayerController {
    private val _state = MutableStateFlow(
        PlayerState(
            phase = PlayerState.Phase.Error,
            error = message,
        ),
    )

    override val state: StateFlow<PlayerState> = _state.asStateFlow()

    override fun setSource(source: PlaySource) = Unit
    override fun play() = Unit
    override fun pause() = Unit
    override fun seekTo(positionMs: Long) = Unit
    override fun setSpeed(speed: Float) = Unit
    override fun release() = Unit
}
