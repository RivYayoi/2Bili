package tv.bili.core

import kotlin.test.Test
import kotlin.test.assertEquals
import tv.bili.core.format.formatCount
import tv.bili.core.format.formatDuration
import tv.bili.core.format.parseDurationToSeconds

class FormattersTest {
    @Test
    fun counts() {
        assertEquals("9999", formatCount(9_999))
        assertEquals("1.2万", formatCount(12_345))
        assertEquals("1亿", formatCount(100_000_000))
    }

    @Test
    fun durations() {
        assertEquals("0:09", formatDuration(9))
        assertEquals("12:34", formatDuration(754))
        assertEquals("1:02:03", formatDuration(3_723))
        assertEquals(754, parseDurationToSeconds("12:34"))
        assertEquals(3_723, parseDurationToSeconds("1:02:03"))
    }
}
