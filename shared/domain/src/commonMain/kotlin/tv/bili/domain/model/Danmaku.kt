package tv.bili.domain.model

data class Danmaku(
    val id: Long,
    /** Position on the video timeline, in milliseconds. */
    val progressMs: Long,
    /** 1-3 scrolling, 4 bottom, 5 top. MVP only renders 1-3. */
    val mode: Int = 1,
    val fontSize: Int = 25,
    /** 0xRRGGBB */
    val color: Long = 0xFFFFFF,
    val content: String,
)
