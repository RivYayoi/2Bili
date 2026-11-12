package tv.bili.data.auth

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import kotlinx.coroutines.CancellationException
import tv.bili.core.error.AppError
import tv.bili.core.result.AppResult
import tv.bili.data.dto.QrGenerateEnvelope
import tv.bili.data.dto.QrPollEnvelope
import tv.bili.domain.model.Credential
import tv.bili.domain.model.QrPoll
import tv.bili.domain.model.QrStatus
import tv.bili.domain.model.QrTicket

class QrLoginApi(
    private val http: HttpClient,
) {

    suspend fun generate(): AppResult<QrTicket> {
        return try {
            val envelope: QrGenerateEnvelope = http
                .get("https://passport.bilibili.com/x/passport-login/web/qrcode/generate")
                .body()

            val data = envelope.data
            if (envelope.code != 0 || data == null) {
                AppResult.Failure(AppError.Api(envelope.code, envelope.message))
            } else {
                AppResult.Success(QrTicket(url = data.url, key = data.qrcodeKey))
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            AppResult.Failure(AppError.Network(e.message))
        }
    }

    suspend fun poll(key: String): AppResult<QrPoll> {
        return try {
            val envelope: QrPollEnvelope = http
                .get("https://passport.bilibili.com/x/passport-login/web/qrcode/poll") {
                    parameter("qrcode_key", key)
                }
                .body()

            val data = envelope.data
                ?: return AppResult.Failure(AppError.Api(envelope.code, envelope.message))

            val status = when (data.code) {
                0 -> QrStatus.Success
                86090 -> QrStatus.Scanned
                86038 -> QrStatus.Expired
                else -> QrStatus.Waiting
            }

            val credential = if (status == QrStatus.Success) {
                parseCredential(data.url, data.refreshToken)
            } else {
                null
            }

            AppResult.Success(
                QrPoll(
                    status = status,
                    message = data.message,
                    credential = credential,
                ),
            )
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            AppResult.Failure(AppError.Network(e.message))
        }
    }

    /**
     * On success bilibili returns a URL whose query string carries the cookies.
     * SESSDATA stays percent-encoded on purpose: it is sent back verbatim in Cookie.
     */
    private fun parseCredential(url: String, refreshToken: String): Credential? {
        if (url.isBlank()) return null

        val query = url.substringAfter('?', "")
        val values = query.split('&')
            .mapNotNull { pair ->
                val index = pair.indexOf('=')
                if (index <= 0) null
                else pair.substring(0, index) to pair.substring(index + 1)
            }
            .toMap()

        val sessData = values["SESSDATA"] ?: return null
        return Credential(
            sessData = sessData,
            biliJct = values["bili_jct"].orEmpty(),
            dedeUserId = values["DedeUserID"].orEmpty(),
            refreshToken = refreshToken,
        )
    }
}
