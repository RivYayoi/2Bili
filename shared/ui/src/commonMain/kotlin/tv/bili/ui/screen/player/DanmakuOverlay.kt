package tv.bili.ui.screen.player

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.flow.Flow
import tv.bili.domain.model.Danmaku
import kotlin.math.abs

private const val DURATION_MS = 8_000L
private const val LANE_COUNT = 10
private const val MAX_ACTIVE = 200

private class ActiveDanmaku(
    val danmaku: Danmaku,
    val startMs: Long,
    val lane: Int,
    val layout: TextLayoutResult,
)

/**
 * A deliberately small danmaku engine:
 *  - 1-3 scrolling danmaku only (MVP)
 *  - lane assignment is round-robin (no collision avoidance yet)
 *  - the timeline is advanced with withFrameNanos, not by player callbacks,
 *    so it stays smooth even though VLC/ExoPlayer report time 4x per second.
 */
@Composable
fun DanmakuOverlay(
    danmaku: Flow<Danmaku>,
    positionMs: Long,
    isPlaying: Boolean,
    enabled: Boolean = true,
    opacity: Float = 1f,
    fontScale: Float = 1f,
    modifier: Modifier = Modifier,
) {
    val pending = remember { mutableStateListOf<Danmaku>() }
    val active = remember { mutableStateListOf<ActiveDanmaku>() }
    var smoothMs by remember { mutableLongStateOf(positionMs) }
    var laneSeed by remember { mutableIntStateOf(0) }

    val textMeasurer = rememberTextMeasurer()

    LaunchedEffect(danmaku) {
        danmaku.collect { item ->
            if (item.mode !in 1..3) return@collect
            if (item.content.isBlank()) return@collect
            pending += item
            pending.sortBy { it.progressMs }
        }
    }

    // Seek detection: a large jump means the user scrubbed, so drop everything.
    LaunchedEffect(positionMs) {
        if (abs(positionMs - smoothMs) > 1_000L) {
            smoothMs = positionMs
            active.clear()
        } else if (positionMs > smoothMs) {
            smoothMs = positionMs
        }
    }

    LaunchedEffect(isPlaying) {
        if (!isPlaying) return@LaunchedEffect
        var lastFrame = withFrameNanos { it }
        while (true) {
            withFrameNanos { now ->
                smoothMs += (now - lastFrame) / 1_000_000L
                lastFrame = now
            }
        }
    }

    val scale = fontScale.coerceIn(0.6f, 2f)
    LaunchedEffect(scale) {
        while (true) {
            withFrameNanos {
                while (pending.isNotEmpty() && pending.first().progressMs <= smoothMs) {
                    val item = pending.removeAt(0)
                    val layout = textMeasurer.measure(
                        text = item.content,
                        style = TextStyle(
                            color = Color(0xFF000000L or (item.color and 0xFFFFFFL)),
                            fontSize = (item.fontSize.coerceIn(12, 36) * 0.72f * scale).sp,
                            fontWeight = FontWeight.Medium,
                        ),
                        maxLines = 1,
                        softWrap = false,
                    )
                    active += ActiveDanmaku(
                        danmaku = item,
                        startMs = item.progressMs,
                        lane = laneSeed % LANE_COUNT,
                        layout = layout,
                    )
                    laneSeed++
                }

                active.removeAll { smoothMs - it.startMs > DURATION_MS }
                if (active.size > MAX_ACTIVE) {
                    repeat(active.size - MAX_ACTIVE) { active.removeAt(0) }
                }
            }
        }
    }

    Canvas(modifier.alpha(if (enabled) opacity.coerceIn(0.1f, 1f) else 0f)) {
        val laneHeight = 30.dp.toPx()
        val topPadding = 8.dp.toPx()
        val speed = (size.width + 400.dp.toPx()) / (DURATION_MS / 1000f)

        active.forEach { item ->
            val elapsedSeconds = ((smoothMs - item.startMs).coerceAtLeast(0L)) / 1000f
            val x = size.width - elapsedSeconds * speed
            if (x + item.layout.size.width >= 0f && x <= size.width) {
                drawText(
                    textLayoutResult = item.layout,
                    topLeft = Offset(x, topPadding + item.lane * laneHeight),
                )
            }
        }
    }
}
