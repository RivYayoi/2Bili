package tv.bili.data.risk

import tv.bili.core.error.AppError
import tv.bili.data.auth.BuvidManager

/**
 * Single decision point for risk-control responses.
 * Repositories must not inspect -352 / -101 themselves.
 */
class RiskControlHandler(
    private val buvid: BuvidManager,
) {
    fun shouldRetry(code: Int, attempt: Int): Boolean =
        code == BiliCode.RISK_CONTROL && attempt < MAX_RETRIES

    suspend fun beforeRetry() {
        buvid.ensure()
    }

    fun map(code: Int, message: String): AppError = when (code) {
        BiliCode.NOT_LOGGED_IN -> AppError.Unauthorized
        BiliCode.RISK_CONTROL -> AppError.RiskControl(code)
        else -> AppError.Api(code, message)
    }

    private companion object {
        const val MAX_RETRIES = 1
    }
}
