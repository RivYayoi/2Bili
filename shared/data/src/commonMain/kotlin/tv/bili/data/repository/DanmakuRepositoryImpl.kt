package tv.bili.data.repository

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import tv.bili.core.error.AppError
import tv.bili.core.result.AppResult
import tv.bili.data.danmaku.DanmakuSource
import tv.bili.domain.model.Danmaku
import tv.bili.domain.repository.DanmakuRepository

class DanmakuRepositoryImpl(
    private val source: DanmakuSource,
) : DanmakuRepository {

    override suspend fun history(cid: Long): AppResult<List<Danmaku>> = try {
        AppResult.Success(source.history(cid))
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        AppResult.Failure(AppError.Network(e.message))
    }

    override fun live(cid: Long): Flow<Danmaku> = source.live(cid)
}
