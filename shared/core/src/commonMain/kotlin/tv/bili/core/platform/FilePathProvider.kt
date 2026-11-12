package tv.bili.core.platform

/**
 * Minimal platform surface for file locations.
 * Never expose java.io.File / android.content.Context through this API.
 */
expect class FilePathProvider() {
    fun appDataDir(): String
    fun cacheDir(): String
}
