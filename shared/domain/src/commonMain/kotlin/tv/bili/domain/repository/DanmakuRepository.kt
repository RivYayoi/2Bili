package tv.bili.domain.repository

import kotlinx.coroutines.flow.Flow
import tv.bili.core.result.AppResult
import tv.bili.domain.model.Danmaku

interface DanmakuRepository {
    /** Historical danmaku for a video part (cid). */
    suspend fun history(cid: Long): AppResult<List<Danmaku>>

    /** Realtime danmaku. The shared layer only consumes the parsed flow. */
    fun live(cid: Long): Flow<Danmaku>
}
