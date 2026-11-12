package tv.bili.data.wbi

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import tv.bili.data.dto.BiliResponse
import tv.bili.data.dto.NavDto
import kotlin.time.Clock

/**
 * Fetches img_key/sub_key from /x/web-interface/nav and caches the derived mixin_key.
 *
 * - Keys rotate roughly daily, so the TTL is deliberately short (6h).
 * - Concurrent callers are de-duplicated by a Mutex.
 * - If nav itself is risk-controlled we fall back to scraping the two
 *   /bfs/wbi/<32 hex>.png URLs out of the homepage HTML.
 */
class NavWbiKeyProvider(
    private val http: HttpClient,
) : WbiKeyProvider {

    private val mutex = Mutex()
    private var cached: Cached? = null

    override suspend fun mixinKey(forceRefresh: Boolean): String = mutex.withLock {
        val now = Clock.System.now().epochSeconds
        val current = cached
        if (!forceRefresh && current != null && now < current.expiresAtEpochSec) {
            return@withLock current.value
        }

        val (imgKey, subKey) = runCatching { fetchFromNav() }
            .getOrElse { fetchFromHomepage() }

        val mixin = mixinKeyOf(imgKey, subKey)
        cached = Cached(mixin, now + TTL_SECONDS)
        mixin
    }

    private suspend fun fetchFromNav(): Pair<String, String> {
        val response: BiliResponse<NavDto> = http
            .get("/x/web-interface/nav")
            .body()

        val nav = response.data ?: error("nav: empty data")
        val wbiImg = nav.wbiImg ?: error("nav: missing wbi_img")
        val img = wbiImg.imgUrl.takeIf { it.isNotBlank() } ?: error("nav: missing wbi_img.img_url")
        val sub = wbiImg.subUrl.takeIf { it.isNotBlank() } ?: error("nav: missing wbi_img.sub_url")

        return keyOf(img) to keyOf(sub)
    }

    private suspend fun fetchFromHomepage(): Pair<String, String> {
        val html: String = http
            .get("https://www.bilibili.com")
            .body()

        val keys = Regex("""/bfs/wbi/([0-9a-f]{32})\.png""")
            .findAll(html)
            .map { it.groupValues[1] }
            .distinct()
            .take(2)
            .toList()

        require(keys.size == 2) { "homepage: wbi keys not found" }
        return keys[0] to keys[1]
    }

    private fun keyOf(url: String): String =
        url.substringAfterLast('/').substringBeforeLast('.')

    private data class Cached(
        val value: String,
        val expiresAtEpochSec: Long,
    )

    private companion object {
        const val TTL_SECONDS = 6 * 60 * 60L
    }
}
