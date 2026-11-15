package tv.bili.core

import kotlin.test.Test
import kotlin.test.assertEquals
import tv.bili.core.format.formatCommentTime

class CommentTimeTest {
    private val now = 1_800_000_000L

    @Test
    fun relativeTimes() {
        assertEquals("刚刚", formatCommentTime(now - 30L, now))
        assertEquals("2分钟前", formatCommentTime(now - 120L, now))
        assertEquals("2小时前", formatCommentTime(now - 7_200L, now))
        assertEquals("3天前", formatCommentTime(now - 259_200L, now))
        assertEquals("2个月前", formatCommentTime(now - 5_184_000L, now))
        assertEquals("1年前", formatCommentTime(now - 31_536_000L, now))
    }

    @Test
    fun invalidTimestamp() {
        assertEquals("", formatCommentTime(0L, now))
    }
}
