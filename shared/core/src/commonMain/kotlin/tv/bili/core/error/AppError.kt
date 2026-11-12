package tv.bili.core.error

sealed interface AppError {
    data class Network(val detail: String? = null) : AppError
    data class Http(val status: Int) : AppError
    data class Api(val code: Int, val message: String) : AppError

    /** -352 / 412 / signature rejection. Never auto-retried more than once. */
    data class RiskControl(val code: Int, val retryAfterMs: Long? = null) : AppError

    data object Unauthorized : AppError
    data class Unexpected(val detail: String? = null) : AppError
}

fun AppError.toUserMessage(): String = when (this) {
    is AppError.Network -> "网络连接失败，请检查网络后重试"
    is AppError.Http -> "服务器返回异常（HTTP $status）"
    is AppError.Api -> when (code) {
        -101 -> "登录已失效，请重新扫码登录"
        -404 -> "内容不存在或已被删除"
        else -> message.ifBlank { "请求失败（$code）" }
    }
    is AppError.RiskControl -> "请求被风控拦截，请稍后再试或更换网络环境"
    AppError.Unauthorized -> "请先扫码登录"
    is AppError.Unexpected -> "出现未知错误"
}
