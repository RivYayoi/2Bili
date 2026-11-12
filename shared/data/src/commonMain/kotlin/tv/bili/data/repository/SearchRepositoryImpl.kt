package tv.bili.data.repository

import tv.bili.core.result.AppResult
import tv.bili.core.result.map
import tv.bili.data.api.BiliApiClient
import tv.bili.data.dto.SearchData
import tv.bili.data.mapper.toVideo
import tv.bili.domain.model.Paged
import tv.bili.domain.model.Video
import tv.bili.domain.repository.SearchRepository

class SearchRepositoryImpl(
    private val api: BiliApiClient,
) : SearchRepository {

    override suspend fun search(keyword: String, page: Int, pageSize: Int): AppResult<Paged<Video>> =
        api.get<SearchData>(
            path = "/x/web-interface/wbi/search/type",
            params = mapOf(
                "search_type" to "video",
                "keyword" to keyword,
                "page" to page.toString(),
                "page_size" to pageSize.toString(),
            ),
            wbi = true,
        ).map { data ->
            val items = data.result
                .map { it.toVideo() }
                .filter { it.bvid.isNotBlank() }
            Paged(
                items = items,
                page = page,
                hasMore = items.size >= pageSize,
            )
        }
}
