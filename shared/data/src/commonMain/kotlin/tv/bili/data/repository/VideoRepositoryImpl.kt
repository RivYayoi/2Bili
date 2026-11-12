package tv.bili.data.repository

import tv.bili.core.result.AppResult
import tv.bili.core.result.map
import tv.bili.data.api.BiliApiClient
import tv.bili.data.dto.PlayUrlDto
import tv.bili.data.dto.PopularDto
import tv.bili.data.dto.RcmdDto
import tv.bili.data.dto.ViewDto
import tv.bili.data.mapper.toDetail
import tv.bili.data.mapper.toDomain
import tv.bili.data.mapper.toVideo
import tv.bili.domain.model.Paged
import tv.bili.domain.model.PlayUrl
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
}
