package tv.bili.domain.repository

import tv.bili.core.result.AppResult
import tv.bili.domain.model.Paged
import tv.bili.domain.model.Video

interface SearchRepository {
    suspend fun search(keyword: String, page: Int, pageSize: Int): AppResult<Paged<Video>>
}
