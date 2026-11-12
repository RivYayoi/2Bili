package tv.bili.data.auth

import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import tv.bili.core.platform.SecureCredentialStore
import tv.bili.domain.model.Credential

class CredentialRepository(
    private val store: SecureCredentialStore,
    private val buvid: BuvidManager,
) : CookieProvider {

    private val json = Json { ignoreUnknownKeys = true }

    private var cached: Credential? = null
    private var loaded: Boolean = false

    suspend fun load(): Credential? {
        if (loaded) return cached
        cached = store.get(KEY)?.let {
            runCatching { json.decodeFromString<StoredCredential>(it).toDomain() }.getOrNull()
        }
        loaded = true
        return cached
    }

    suspend fun save(credential: Credential) {
        cached = credential
        loaded = true
        store.put(KEY, json.encodeToString(StoredCredential.from(credential)))
    }

    suspend fun clear() {
        cached = null
        loaded = true
        store.remove(KEY)
    }

    override suspend fun cookieHeader(): String? {
        val credential = load()
        val buvidCookie = buvid.cookieHeader()

        return when {
            credential == null && buvidCookie.isBlank() -> null
            credential == null -> buvidCookie
            else -> buildString {
                append("SESSDATA=").append(credential.sessData)
                append("; bili_jct=").append(credential.biliJct)
                append("; DedeUserID=").append(credential.dedeUserId)
                if (buvidCookie.isNotBlank()) append("; ").append(buvidCookie)
            }
        }
    }

    private companion object {
        const val KEY = "bili_credential"
    }
}

@Serializable
private data class StoredCredential(
    val sessData: String,
    val biliJct: String,
    val dedeUserId: String,
    val refreshToken: String = "",
) {
    fun toDomain() = Credential(
        sessData = sessData,
        biliJct = biliJct,
        dedeUserId = dedeUserId,
        refreshToken = refreshToken,
    )

    companion object {
        fun from(credential: Credential) = StoredCredential(
            sessData = credential.sessData,
            biliJct = credential.biliJct,
            dedeUserId = credential.dedeUserId,
            refreshToken = credential.refreshToken,
        )
    }
}
