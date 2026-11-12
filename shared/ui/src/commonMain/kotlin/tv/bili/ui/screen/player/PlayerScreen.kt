package tv.bili.ui.screen.player

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.compose.viewmodel.koinViewModel
import tv.bili.core.format.formatDuration
import tv.bili.domain.model.VideoQuality
import tv.bili.domain.player.PlayerState
import tv.bili.ui.component.ErrorView
import tv.bili.ui.player.PlatformVideoSurface
import tv.bili.ui.player.rememberPlayerController

@Composable
fun PlayerScreen(
    bvid: String,
    cid: Long,
    title: String,
    onBack: () -> Unit,
    viewModel: PlayerViewModel = koinViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val controller = rememberPlayerController()
    val playerState by controller.state.collectAsStateWithLifecycle()

    LaunchedEffect(bvid, cid) {
        viewModel.load(bvid, cid)
    }

    val source = state.playUrl?.source(state.selectedQn)
    LaunchedEffect(source) {
        if (source != null) {
            controller.setSource(source)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
    ) {
        PlatformVideoSurface(
            controller = controller,
            modifier = Modifier.fillMaxSize(),
        )

        DanmakuOverlay(
            danmaku = viewModel.danmaku,
            positionMs = playerState.positionMs,
            isPlaying = playerState.isPlaying,
            modifier = Modifier.fillMaxSize(),
        )

        TopBar(
            title = title,
            qualities = state.playUrl?.qualities.orEmpty(),
            selectedQn = state.selectedQn,
            onBack = onBack,
            onSelectQuality = viewModel::selectQuality,
            modifier = Modifier.align(Alignment.TopCenter),
        )

        when {
            state.isLoading -> CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center),
                color = Color.White,
            )

            state.error != null -> ErrorView(
                error = state.error!!,
                onRetry = viewModel::retry,
                modifier = Modifier.align(Alignment.Center),
            )

            playerState.phase == PlayerState.Phase.Error -> Column(
                modifier = Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("播放失败", color = Color.White)
                playerState.error?.let {
                    Text(it, color = Color(0xFFFF8A80), style = MaterialTheme.typography.bodySmall)
                }
            }
        }

        BottomControls(
            playerState = playerState,
            onTogglePlay = {
                if (playerState.isPlaying) controller.pause() else controller.play()
            },
            onSeek = controller::seekTo,
            onSpeed = controller::setSpeed,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

@Composable
private fun TopBar(
    title: String,
    qualities: List<VideoQuality>,
    selectedQn: Int,
    onBack: () -> Unit,
    onSelectQuality: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.38f))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回", tint = Color.White)
        }
        Text(
            text = title,
            modifier = Modifier.weight(1f),
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            style = MaterialTheme.typography.titleSmall,
        )
        QualityMenu(
            qualities = qualities,
            selectedQn = selectedQn,
            onSelect = onSelectQuality,
        )
    }
}

@Composable
private fun QualityMenu(
    qualities: List<VideoQuality>,
    selectedQn: Int,
    onSelect: (Int) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedLabel = qualities.firstOrNull { it.qn == selectedQn }?.label ?: "画质"

    Box {
        TextButton(onClick = { expanded = true }) {
            Text(selectedLabel, color = Color.White)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            qualities.forEach { quality ->
                DropdownMenuItem(
                    text = { Text(quality.label) },
                    onClick = {
                        onSelect(quality.qn)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun BottomControls(
    playerState: PlayerState,
    onTogglePlay: () -> Unit,
    onSeek: (Long) -> Unit,
    onSpeed: (Float) -> Unit,
    modifier: Modifier = Modifier,
) {
    var dragging by remember { mutableStateOf(false) }
    var dragPosition by remember { mutableFloatStateOf(0f) }

    val duration = playerState.durationMs.coerceAtLeast(1L)
    val shownPosition = if (dragging) dragPosition.toLong() else playerState.positionMs

    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.55f))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        IconButton(onClick = onTogglePlay) {
            Icon(
                imageVector = if (playerState.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                contentDescription = if (playerState.isPlaying) "暂停" else "播放",
                tint = Color.White,
            )
        }

        Text(
            text = formatDuration((shownPosition / 1000L).toInt()),
            color = Color.White,
            style = MaterialTheme.typography.labelSmall,
        )

        Slider(
            value = (shownPosition.toFloat() / duration).coerceIn(0f, 1f),
            onValueChange = {
                dragging = true
                dragPosition = it * duration
            },
            onValueChangeFinished = {
                onSeek(dragPosition.toLong())
                dragging = false
            },
            modifier = Modifier.weight(1f),
        )

        Text(
            text = formatDuration((duration / 1000L).toInt()),
            color = Color.White,
            style = MaterialTheme.typography.labelSmall,
        )

        Spacer(Modifier.width(4.dp))

        SpeedMenu(currentSpeed = playerState.speed, onSpeed = onSpeed)
    }
}

@Composable
private fun SpeedMenu(
    currentSpeed: Float,
    onSpeed: (Float) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }

    Box {
        TextButton(onClick = { expanded = true }) {
            Text("${currentSpeed}x", color = Color.White)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            listOf(0.5f, 0.75f, 1f, 1.25f, 1.5f, 2f).forEach { speed ->
                DropdownMenuItem(
                    text = { Text("${speed}x") },
                    onClick = {
                        onSpeed(speed)
                        expanded = false
                    },
                )
            }
        }
    }
}
