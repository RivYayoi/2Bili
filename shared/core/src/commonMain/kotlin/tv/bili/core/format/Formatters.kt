package tv.bili.core.format

import kotlin.math.roundToLong

/** 12345 -> "1.2万", 123456789 -> "1.2亿" */
fun formatCount(count: Long): String = when {
    count >= 100_000_000L -> "${oneDecimal(count / 100_000_000.0)}亿"
    count >= 10_000L -> "${oneDecimal(count / 10_000.0)}万"
    else -> count.toString()
}

/** 754 -> "12:34", 3723 -> "1:02:03" */
fun formatDuration(totalSeconds: Int): String {
    val seconds = totalSeconds.coerceAtLeast(0)
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) {
        "$h:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}"
    } else {
        "$m:${s.toString().padStart(2, '0')}"
    }
}

/** "12:34" / "1:02:03" / "754" -> seconds, null if unparseable */
fun parseDurationToSeconds(raw: String): Int? {
    val text = raw.trim()
    if (text.isEmpty()) return null
    text.toIntOrNull()?.let { return it }
    val parts = text.split(':').mapNotNull { it.toIntOrNull() }
    if (parts.size !in 2..3) return null
    return when (parts.size) {
        2 -> parts[0] * 60 + parts[1]
        else -> parts[0] * 3600 + parts[1] * 60 + parts[2]
    }
}

private fun oneDecimal(value: Double): String {
    val rounded = (value * 10).roundToLong() / 10.0
    return if (rounded % 1.0 == 0.0) rounded.toLong().toString() else rounded.toString()
}
