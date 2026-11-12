package tv.bili.data.auth

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.serialization.kotlinx.json.json
import tv.bili.core.platform.SecureCredentialStore
import tv.bili.data.api.BiliJson
import tv.bili.data.dto.BiliResponse
import tv.bili.data.dto.SpiData
import kotlin.concurrent.Volatile

/**
 * buvid3/buvid4 are required by a lot of web endpoints and their absence is a
 * very common cause of -352. They are fetched once and persisted.
 */
class BuvidManager(
    engine: HttpClientEngine,
    private val store: SecureCredentialStore,
) {
    private val http = HttpClient(engine) {
        install(ContentNegotiation) { json(BiliJson) }
    }

    @Volatile
    private var cached: Pair<String, String>? = null

    suspend fun ensure() {
        if (cached != null) return

        val stored3 = store.get(KEY_BUVID3)
        val stored4 = store.get(KEY_BUVID4)
        if (!stored3.isNullOrBlank() && !stored4.isNullOrBlank()) {
            cached = stored3 to stored4
            return
        }

        val response = runCatching {
            http.get("https://api.bilibili.com/x/frontend/finger/spi")
                .body<BiliResponse<SpiData>>()
        }.getOrNull()

        val data = response?.data ?: return
        if (data.buvid3.isNotBlank()) store.put(KEY_BUVID3, data.buvid3)
        if (data.buvid4.isNotBlank()) store.put(KEY_BUVID4, data.buvid4)
        cached = data.buvid3 to data.buvid4
    }

    suspend fun cookieHeader(): String {
        ensure()
        val (buvid3, buvid4) = cached ?: return ""
        return buildString {
            if (buvid3.isNotBlank()) append("buvid3=").append(buvid3)
            if (buvid4.isNotBlank()) {
                if (isNotEmpty()) append("; ")
                append("buvid4=").append(buvid4)
            }
        }
    }

    private companion object {
        const val KEY_BUVID3 = "buvid3"
        const val KEY_BUVID4 = "buvid4"
    }
}
