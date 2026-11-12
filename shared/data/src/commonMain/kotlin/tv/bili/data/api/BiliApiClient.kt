package tv.bili.data.api

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.http.HttpHeaders
import io.ktor.http.isSuccess
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import tv.bili.core.error.AppError
import tv.bili.core.result.AppResult
import tv.bili.data.auth.CookieProvider
import tv.bili.data.dto.BiliResponse
import tv.bili.data.risk.RiskControlHandler
import tv.bili.data.wbi.WbiSigner

/**
 * The single HTTP choke point:
 *  - WBI signing happens here (never in repositories)
 *  - Cookie injection happens here
 *  - -352 retry (max once) and 412 handling happen here
 */
class BiliApiClient(
    internal val http: HttpClient,
    internal val signer: WbiSigner,
    internal val risk: RiskControlHandler,
    internal val cookies: CookieProvider,
) {

    internal suspend inline fun <reified T> get(
        path: String,
        params: Map<String, String> = emptyMap(),
        wbi: Boolean = false,
    ): AppResult<T> {
        var attempt = 0

        while (true) {
            val finalParams = if (wbi) signer.sign(params) else params
            // CookieProvider is suspend, so resolve it before the (non-suspend)
            // request builder runs.
            val cookie = cookies.cookieHeader()

            val response = try {
                http.get(path) {
                    finalParams.forEach { (key, value) -> parameter(key, value) }
                    cookie?.let { header(HttpHeaders.Cookie, it) }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                return AppResult.Failure(AppError.Network(e.message))
            }

            if (response.status.value == 412) {
                return AppResult.Failure(AppError.RiskControl(412))
            }
            if (!response.status.isSuccess()) {
                return AppResult.Failure(AppError.Http(response.status.value))
            }

            val envelope = try {
                response.body<BiliResponse<T>>()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                return AppResult.Failure(AppError.Unexpected("decode failed: ${e.message}"))
            }

            when {
                envelope.code == 0 -> {
                    val data = envelope.data
                    return if (data == null) {
                        AppResult.Failure(AppError.Unexpected("empty data"))
                    } else {
                        AppResult.Success(data)
                    }
                }

                risk.shouldRetry(envelope.code, attempt) -> {
                    attempt++
                    risk.beforeRetry()
                    signer.invalidateKeys()
                    delay(350L + attempt * 250L)
                }

                else -> return AppResult.Failure(risk.map(envelope.code, envelope.message))
            }
        }
    }
}
