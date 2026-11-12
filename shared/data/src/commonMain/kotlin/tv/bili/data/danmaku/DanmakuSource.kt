package tv.bili.data.danmaku

import kotlinx.coroutines.flow.Flow
import tv.bili.domain.model.Danmaku

/**
 * Platform boundary for danmaku.
 *
 * Desktop: java.net.http.WebSocket + java.util.zip.Inflater
 * Android: OkHttp WebSocket + Inflater
 *
 * The shared layer only ever sees Flow<Danmaku>.
 */
expect class DanmakuSource() {
    suspend fun history(cid: Long): List<Danmaku>
    fun live(cid: Long): Flow<Danmaku>
}
