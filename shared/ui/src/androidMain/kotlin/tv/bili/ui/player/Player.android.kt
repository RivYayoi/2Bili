package tv.bili.ui.player

import androidx.annotation.OptIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.PlayerView
import tv.bili.domain.player.PlayerController

@Composable
actual fun rememberPlayerController(): PlayerController {
    val context = LocalContext.current
    val controller = remember(context) { ExoPlayerController(context) }

    DisposableEffect(controller) {
        onDispose { controller.release() }
    }

    return controller
}

@OptIn(UnstableApi::class)
@Composable
actual fun PlatformVideoSurface(
    controller: PlayerController,
    modifier: Modifier,
) {
    val exo = controller as? ExoPlayerController ?: return

    AndroidView(
        factory = { context ->
            PlayerView(context).apply {
                player = exo.player
                useController = false
            }
        },
        modifier = modifier,
    )
}
