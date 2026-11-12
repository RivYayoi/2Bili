package tv.bili.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class PlayUrlDto(
    val quality: Int = 0,
    @SerialName("accept_quality") val acceptQuality: List<Int> = emptyList(),
    @SerialName("accept_description") val acceptDescription: List<String> = emptyList(),
    val durl: List<DurlDto> = emptyList(),
    val dash: DashDto? = null,
)

@Serializable
data class DurlDto(
    val order: Int = 0,
    val length: Long = 0L,
    val size: Long = 0L,
    val url: String = "",
)

@Serializable
data class DashDto(
    val duration: Long = 0L,
    val video: List<DashStreamDto> = emptyList(),
    val audio: List<DashStreamDto> = emptyList(),
)

@Serializable
data class DashStreamDto(
    val id: Int = 0,
    @SerialName("baseUrl") val baseUrl: String = "",
    @SerialName("backupUrl") val backupUrl: List<String> = emptyList(),
    val bandwidth: Long = 0L,
    /** 7 = AVC/H.264, 12 = HEVC/H.265, 13 = AV1. 0 for audio streams. */
    val codecid: Int = 0,
    val codecs: String? = null,
    val width: Int = 0,
    val height: Int = 0,
)
