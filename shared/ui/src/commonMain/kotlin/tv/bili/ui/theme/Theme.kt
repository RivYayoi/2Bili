package tv.bili.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val BiliPink = Color(0xFFFB7299)
private val BiliBlue = Color(0xFF00AEEC)

private val DarkColors = darkColorScheme(
    primary = BiliPink,
    onPrimary = Color.White,
    secondary = BiliBlue,
    onSecondary = Color.White,
    background = Color(0xFF121212),
    onBackground = Color(0xFFEDEDED),
    surface = Color(0xFF1A1A1A),
    onSurface = Color(0xFFEDEDED),
    surfaceVariant = Color(0xFF262626),
    onSurfaceVariant = Color(0xFFB5B5B5),
    error = Color(0xFFFF6B6B),
)

@Composable
fun BiliTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColors,
        content = content,
    )
}
