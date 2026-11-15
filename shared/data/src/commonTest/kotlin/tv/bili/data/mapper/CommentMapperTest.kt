package tv.bili.data.mapper

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import tv.bili.data.dto.ReplyContentDto
import tv.bili.data.dto.ReplyDto
import tv.bili.data.dto.ReplyMemberDto

class CommentMapperTest {
    @Test
    fun mapsMemberAndUploaderFlag() {
        val dto = ReplyDto(
            rpid = 42L,
            mid = 1L,
            ctime = 1_700_000_000L,
            like = 7L,
            rcount = 2,
            member = ReplyMemberDto(
                mid = "99",
                uname = "测试用户",
                avatar = "//i0.hdslb.com/avatar.jpg",
            ),
            content = ReplyContentDto(message = "你好"),
            replies = listOf(
                ReplyDto(
                    rpid = 43L,
                    mid = 2L,
                    member = ReplyMemberDto(mid = "100", uname = "回复者"),
                    content = ReplyContentDto(message = "回复"),
                ),
            ),
        )

        val comment = dto.toComment(upperMid = 99L)

        assertEquals(42L, comment.rpid)
        assertEquals(99L, comment.mid)
        assertEquals("测试用户", comment.userName)
        assertEquals("https://i0.hdslb.com/avatar.jpg", comment.avatarUrl)
        assertEquals("你好", comment.message)
        assertEquals(7L, comment.likeCount)
        assertEquals(2, comment.replyCount)
        assertTrue(comment.isUploader)
        assertEquals(1, comment.replies.size)
        assertEquals("回复", comment.replies.single().message)
        assertFalse(comment.replies.single().isUploader)
    }

    @Test
    fun fallsBackWhenMemberIsMissing() {
        val comment = ReplyDto(rpid = 1L, mid = 123L).toComment(upperMid = 0L)

        assertEquals(123L, comment.mid)
        assertEquals("匿名用户", comment.userName)
        assertEquals("", comment.avatarUrl)
        assertFalse(comment.isUploader)
    }
}
