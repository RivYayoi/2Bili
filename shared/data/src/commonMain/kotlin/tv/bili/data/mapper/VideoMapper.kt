package tv.bili.data.mapper

import tv.bili.core.format.parseDurationToSeconds
import tv.bili.data.dto.SearchItemDto
import tv.bili.data.dto.VideoItemDto
import tv.bili.data.dto.ViewDto
import tv.bili.domain.model.Video
import tv.bili.domain.model.VideoDetail
import tv.bili.domain.model.VideoPage

internal fun String.normalizeBiliUrl(): String = when {
    isBlank() -> ""
    startsWith("//") -> "https:$this"
    else -> this
}

internal fun VideoItemDto.toVideo(): Video = Video(
    bvid = bvid,
    aid = aid,
    title = title.ifBlank { "无标题" },
    coverUrl = pic.normalizeBiliUrl(),
    durationSec = duration.toInt(),
    ownerName = owner?.name.orEmpty(),
    viewCount = stat?.view ?: 0L,
    danmakuCount = stat?.danmaku ?: 0L,
)

internal fun ViewDto.toDetail(): VideoDetail {
    val pageList = if (pages.isNotEmpty()) {
        pages.map {
            VideoPage(
                cid = it.cid,
                page = it.page,
                title = it.part,
                durationSec = it.duration.toInt(),
            )
        }
    } else {
        listOf(VideoPage(cid = cid, page = 1, title = title, durationSec = duration.toInt()))
    }

    return VideoDetail(
        bvid = bvid,
        aid = aid,
        title = title.ifBlank { "无标题" },
        coverUrl = pic.normalizeBiliUrl(),
        description = desc,
        durationSec = duration.toInt(),
        ownerName = owner?.name.orEmpty(),
        ownerFaceUrl = owner?.face.orEmpty().normalizeBiliUrl(),
        viewCount = stat?.view ?: 0L,
        danmakuCount = stat?.danmaku ?: 0L,
        pages = pageList,
    )
}

internal fun SearchItemDto.toVideo(): Video = Video(
    bvid = bvid,
    title = title.replace(Regex("<[^>]+>"), ""),
    coverUrl = pic.normalizeBiliUrl(),
    durationSec = parseDurationToSeconds(duration) ?: 0,
    ownerName = author,
    viewCount = play,
    danmakuCount = danmaku,
)
