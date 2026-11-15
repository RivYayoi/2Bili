package tv.bili.core.format

actual fun currentEpochSeconds(): Long = System.currentTimeMillis() / 1_000L
