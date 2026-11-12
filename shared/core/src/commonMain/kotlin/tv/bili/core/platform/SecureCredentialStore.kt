package tv.bili.core.platform

/**
 * Credential storage.
 *
 * Desktop  -> Windows DPAPI (CryptProtectData)
 * Android  -> Android Keystore (AES/GCM) + SharedPreferences
 *
 * Values are opaque strings; callers store JSON, never raw cookies in plain files.
 */
expect class SecureCredentialStore() {
    suspend fun put(key: String, value: String)
    suspend fun get(key: String): String?
    suspend fun remove(key: String)
    suspend fun clear()
}
