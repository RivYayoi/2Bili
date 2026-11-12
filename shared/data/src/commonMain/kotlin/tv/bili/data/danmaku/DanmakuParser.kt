package tv.bili.data.danmaku

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.longOrNull
import tv.bili.domain.model.Danmaku

private val D_TAG = Regex("""<d p="([^"]*)"[^>]*>([^<]*)</d>""")

/**
 * Historical danmaku endpoint returns deflate-compressed XML.
 * Platform actuals only decompress bytes; parsing is shared.
 */
internal fun parseDanmakuXml(xml: String): List<Danmaku> =
    D_TAG.findAll(xml).mapNotNull { match ->
        val parts = match.groupValues[1].split(',')
        if (parts.size < 4) return@mapNotNull null

        val progressMs = ((parts[0].toDoubleOrNull() ?: 0.0) * 1000.0).toLong()
        val content = unescapeXml(match.groupValues[2])
        if (content.isBlank()) return@mapNotNull null

        Danmaku(
            id = parts.getOrNull(7)?.toLongOrNull() ?: 0L,
            progressMs = progressMs,
            mode = parts[1].toIntOrNull() ?: 1,
            fontSize = parts[2].toIntOrNull() ?: 25,
            color = parts[3].toLongOrNull() ?: 0xFFFFFF,
            content = content,
        )
    }.toList()

/**
 * Realtime endpoint is consumed as zlib-compressed JSON (protover=2) on purpose:
 * it keeps the scaffold protobuf-free. Production should switch to
 * protover=3 + zlib/brotli + DmSegMobileReply protobuf.
 */
internal fun parseDanmakuJson(text: String): List<Danmaku> {
    val root = runCatching { Json.parseToJsonElement(text) }.getOrNull() as? JsonObject
        ?: return emptyList()

    val cmd = (root["cmd"] as? JsonPrimitive)?.contentOrNull.orEmpty()
    if (!cmd.startsWith("DANMU_MSG")) return emptyList()

    val info = root["info"] as? JsonArray ?: return emptyList()
    val meta = info.getOrNull(0) as? JsonArray ?: return emptyList()

    val content = (info.getOrNull(1) as? JsonPrimitive)?.contentOrNull
        ?.takeIf { it.isNotBlank() }
        ?: return emptyList()

    return listOf(
        Danmaku(
            id = 0L,
            progressMs = (meta.getOrNull(0) as? JsonPrimitive)?.longOrNull ?: 0L,
            mode = (meta.getOrNull(1) as? JsonPrimitive)?.intOrNull ?: 1,
            fontSize = (meta.getOrNull(2) as? JsonPrimitive)?.intOrNull ?: 25,
            color = (meta.getOrNull(3) as? JsonPrimitive)?.longOrNull ?: 0xFFFFFF,
            content = content,
        ),
    )
}

private fun unescapeXml(value: String): String = value
    .replace("&lt;", "<")
    .replace("&gt;", ">")
    .replace("&quot;", "\"")
    .replace("&apos;", "'")
    .replace("&amp;", "&")
