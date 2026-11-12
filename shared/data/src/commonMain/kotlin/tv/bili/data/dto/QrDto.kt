package tv.bili.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class QrGenerateEnvelope(
    val code: Int = -1,
    val message: String = "",
    val data: QrGenerateData? = null,
)

@Serializable
data class QrGenerateData(
    val url: String = "",
    @SerialName("qrcode_key") val qrcodeKey: String = "",
)

@Serializable
data class QrPollEnvelope(
    val code: Int = -1,
    val message: String = "",
    val data: QrPollData? = null,
)

@Serializable
data class QrPollData(
    val url: String = "",
    @SerialName("refresh_token") val refreshToken: String = "",
    val timestamp: Long = 0L,
    val code: Int = 0,
    val message: String = "",
)
