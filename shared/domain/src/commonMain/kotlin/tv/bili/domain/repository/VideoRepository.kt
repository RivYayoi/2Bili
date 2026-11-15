package tv.bili.domain.repository

import tv.bili.core.result.AppResult
import tv.bili.domain.model.CommentPage
import tv.bili.domain.model.CommentSort
import tv.bili.domain.model.Paged
import tv.bili.domain.model.PlayUrl
import tv.bili.domain.model.ReplyPage
import tv.bili.domain.model.Video
import tv.bili.domain.model.VideoDetail

interface VideoRepository {
    suspend fun recommend(page: Int, pageSize: Int): AppResult<Paged<Video>>
    suspend fun popular(page: Int, pageSize: Int): AppResult<Paged<Video>>
    suspend fun detail(bvid: String): AppResult<VideoDetail>
    suspend fun playUrl(bvid: String, cid: Long, qn: Int): AppResult<PlayUrl>
    suspend fun comments(aid: Long, sort: CommentSort, offset: String? = null): AppResult<CommentPage>
    suspend fun replies(aid: Long, root: Long, page: Int = 1): AppResult<ReplyPage>
}
