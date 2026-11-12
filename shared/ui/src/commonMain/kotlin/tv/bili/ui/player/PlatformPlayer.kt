package tv.bili.ui.player

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import tv.bili.domain.player.PlayerController

/**
 * The only two platform-specific pieces of the player.
 *
 * Everything else (controls, quality menu, danmaku overlay) is plain Compose
 * in commonMain, which is what keeps the Android port cheap.
 */
@Composable
expect fun rememberPlayerController(): PlayerController

@Composable
expect fun PlatformVideoSurface(
    controller: PlayerController,
    modifier: Modifier,
)
