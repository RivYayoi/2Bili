package tv.bili.core.format

expect fun currentEpochSeconds(): Long

/** Formats a Unix timestamp (seconds) as a compact relative time. */
fun formatCommentTime(
    epochSeconds: Long,
    nowSeconds: Long = currentEpochSeconds(),
): String {
    if (epochSeconds <= 0L) return ""
    val seconds = (nowSeconds - epochSeconds).coerceAtLeast(0L)
    return when {
        seconds < 60L -> "刚刚"
        seconds < 3_600L -> "${seconds / 60L}分钟前"
        seconds < 86_400L -> "${seconds / 3_600L}小时前"
        seconds < 2_592_000L -> "${seconds / 86_400L}天前"
        seconds < 31_536_000L -> "${seconds / 2_592_000L}个月前"
        else -> "${seconds / 31_536_000L}年前"
    }
}
