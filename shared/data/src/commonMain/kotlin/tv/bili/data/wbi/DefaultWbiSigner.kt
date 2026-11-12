package tv.bili.data.wbi

import io.ktor.http.encodeURLParameter
import kotlin.time.Clock
import okio.ByteString.Companion.encodeUtf8

class DefaultWbiSigner(
    private val keys: WbiKeyProvider,
) : WbiSigner {

    override suspend fun sign(params: Map<String, String>): Map<String, String> {
        val wts = Clock.System.now().epochSeconds.toString()
        return signAt(params, wts, keys.mixinKey())
    }

    override suspend fun invalidateKeys() {
        keys.mixinKey(forceRefresh = true)
    }

    /**
     * Pure function, kept internal so it can be locked down by a golden-vector unit test.
     */
    internal fun signAt(
        params: Map<String, String>,
        wts: String,
        mixinKey: String,
    ): Map<String, String> {
        val all = params.toMutableMap().apply {
            remove("w_rid")
            put("wts", wts)
        }

        val query = all.entries
            .sortedBy { it.key }
            .joinToString("&") { (key, value) ->
                "${key.wbiEncode()}=${value.wbiEncode()}"
            }

        val wRid = (query + mixinKey).encodeUtf8().md5().hex()
        return all + ("w_rid" to wRid)
    }

    private fun String.wbiEncode(): String =
        filterNot { it in "!'()*" }.encodeURLParameter()
}
