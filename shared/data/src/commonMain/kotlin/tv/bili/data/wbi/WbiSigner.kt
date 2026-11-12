package tv.bili.data.wbi

interface WbiSigner {
    /** Returns params + wts + w_rid. The input map is not mutated. */
    suspend fun sign(params: Map<String, String>): Map<String, String>

    /** Called after a -352 / signature rejection to force a key refresh. */
    suspend fun invalidateKeys()
}

interface WbiKeyProvider {
    suspend fun mixinKey(forceRefresh: Boolean = false): String
}
