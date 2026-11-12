package tv.bili.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class BiliResponse<T>(
    val code: Int = -1,
    val message: String = "",
    val ttl: Int = 1,
    val data: T? = null,
)

@Serializable
data class NavDto(
    @SerialName("isLogin") val isLogin: Boolean = false,
    @SerialName("wbi_img") val wbiImg: WbiImgDto? = null,
    val mid: Long = 0L,
    val uname: String = "",
    val face: String = "",
)

@Serializable
data class WbiImgDto(
    @SerialName("img_url") val imgUrl: String = "",
    @SerialName("sub_url") val subUrl: String = "",
)

@Serializable
data class SpiData(
    @SerialName("b_3") val buvid3: String = "",
    @SerialName("b_4") val buvid4: String = "",
)
