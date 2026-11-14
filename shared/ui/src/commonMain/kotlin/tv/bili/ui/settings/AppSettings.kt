package tv.bili.ui.settings

import kotlinx.serialization.Serializable

const val QUALITY_AUTO = 0
const val QUALITY_1080P = 80
const val QUALITY_720P = 64
const val QUALITY_480P = 32
const val QUALITY_360P = 16

/**
 * User-visible preferences. Kept in the UI layer because they only affect
 * presentation/player defaults, not the domain or network layers.
 */
@Serializable
data class AppSettings(
    val defaultQuality: Int = QUALITY_720P,
    val danmakuEnabled: Boolean = true,
    val danmakuOpacity: Float = 1f,
    val danmakuFontScale: Float = 1f,
)

data class QualityOption(val qn: Int, val label: String)

val qualityOptions = listOf(
    QualityOption(QUALITY_AUTO, "自动"),
    QualityOption(QUALITY_1080P, "1080P"),
    QualityOption(QUALITY_720P, "720P"),
    QualityOption(QUALITY_480P, "480P"),
    QualityOption(QUALITY_360P, "360P"),
)
