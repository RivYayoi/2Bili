package tv.bili.data.repository

import kotlinx.serialization.encodeToString
import tv.bili.core.result.AppResult
import tv.bili.core.result.map
import tv.bili.data.api.BiliApiClient
import tv.bili.data.api.BiliJson
import tv.bili.data.dto.PlayUrlDto
import tv.bili.data.dto.PopularDto
import tv.bili.data.dto.RcmdDto
import tv.bili.data.dto.ReplyMainDto
import tv.bili.data.dto.ReplyPaginationRequest
import tv.bili.data.dto.ViewDto
import tv.bili.data.mapper.toComment
import tv.bili.data.mapper.toDetail
import tv.bili.data.mapper.toDomain
import tv.bili.data.mapper.toVideo
import tv.bili.domain.model.CommentPage
import tv.bili.domain.model.CommentSort
import tv.bili.domain.model.Paged
import tv.bili.domain.model.PlayUrl
import tv.bili.domain.model.ReplyPage
import tv.bili.domain.model.Video
import tv.bili.domain.model.VideoDetail
import tv.bili.domain.repository.VideoRepository

class VideoRepositoryImpl(
    private val api: BiliApiClient,
) : VideoRepository {

    override suspend fun recommend(page: Int, pageSize: Int): AppResult<Paged<Video>> {
        val result = api.get<RcmdDto>(
            path = "/x/web-interface/wbi/index/top/feed/rcmd",
            params = mapOf(
                "ps" to pageSize.toString(),
                "fresh_type" to "4",
                "fresh_idx" to page.toString(),
                "feed_version" to "V8",
                "homepage_ver" to "1",
                "screen" to "1920x1080",
            ),
            wbi = true,
        )

        return when (result) {
            is AppResult.Success -> {
                val items = result.value.item
                    .map { it.toVideo() }
                    .filter { it.bvid.isNotBlank() }
                AppResult.Success(Paged(items, page, hasMore = items.isNotEmpty()))
            }
            // Home feed is the one place where a silent degradation is acceptable:
            // anonymous / risk-controlled clients fall back to the non-WBI popular list.
            is AppResult.Failure -> popular(page, pageSize)
        }
    }

    override suspend fun popular(page: Int, pageSize: Int): AppResult<Paged<Video>> =
        api.get<PopularDto>(
            path = "/x/web-interface/popular",
            params = mapOf(
                "pn" to page.toString(),
                "ps" to pageSize.toString(),
            ),
        ).map { dto ->
            val items = dto.list
                .map { it.toVideo() }
                .filter { it.bvid.isNotBlank() }
            Paged(items, page, hasMore = !dto.noMore && items.isNotEmpty())
        }

    override suspend fun detail(bvid: String): AppResult<VideoDetail> =
        api.get<ViewDto>(
            path = "/x/web-interface/view",
            params = mapOf("bvid" to bvid),
        ).map { it.toDetail() }

    override suspend fun playUrl(bvid: String, cid: Long, qn: Int): AppResult<PlayUrl> =
        api.get<PlayUrlDto>(
            path = "/x/player/wbi/playurl",
            params = mapOf(
                "bvid" to bvid,
                "cid" to cid.toString(),
                "qn" to qn.toString(),
                "fnval" to "4048",
                "fnver" to "0",
                "fourk" to "1",
            ),
            wbi = true,
        ).map { it.toDomain() }

    override suspend fun comments(
        aid: Long,
        sort: CommentSort,
        offset: String?,
    ): AppResult<CommentPage> =
        api.get<ReplyMainDto>(
            path = "/x/v2/reply/wbi/main",
            params = mapOf(
                "oid" to aid.toString(),
                "type" to "1",
                "mode" to sort.apiMode.toString(),
                "pagination_str" to BiliJson.encodeToString(
                    ReplyPaginationRequest(offset.orEmpty()),
                ),
                "plat" to "1",
                "web_location" to "1315875",
            ),
            wbi = true,
            // Anonymous requests that carry a buvid cookie are currently
            // throttled to a 3-comment preview by the main comment endpoint.
            // The endpoint is public, so omit cookies to get the real pages.
            withCookies = false,
        ).map { dto ->
            val upperMid = dto.upper?.mid ?: 0L
            val items = (dto.topReplies + dto.replies)
                .asSequence()
                .filter { it.rpid > 0L }
                .distinctBy { it.rpid }
                .map { it.toComment(upperMid) }
                .toList()
            val cursor = dto.cursor
            val nextOffset = cursor?.paginationReply?.nextOffset?.takeIf { it.isNotBlank() }
            CommentPage(
                items = items,
                totalCount = cursor?.allCount ?: 0L,
                hasMore = cursor?.isEnd == false && nextOffset != null,
                nextOffset = nextOffset,
            )
        }

    override suspend fun replies(
        aid: Long,
        root: Long,
        page: Int,
    ): AppResult<ReplyPage> =
        api.get<ReplyMainDto>(
            path = "/x/v2/reply/reply",
            params = mapOf(
                "type" to "1",
                "oid" to aid.toString(),
                "root" to root.toString(),
                "pn" to page.toString(),
                "ps" to "20",
                "nohot" to "0",
            ),
        ).map { dto ->
            val upperMid = dto.upper?.mid ?: 0L
            val items = dto.replies
                .asSequence()
                .filter { it.rpid > 0L }
                .map { it.toComment(upperMid) }
                .toList()
            val totalCount = dto.page?.count ?: 0L
            val pageSize = dto.page?.size?.takeIf { it > 0 } ?: 20
            val hasMore = page * pageSize < totalCount
            ReplyPage(
                items = items,
                totalCount = totalCount,
                hasMore = hasMore,
                nextPage = if (hasMore) page + 1 else null,
            )
        }
}
