package tv.bili.core.platform

actual class FilePathProvider {
    actual fun appDataDir(): String =
        AndroidPlatformContext.appContext.filesDir.absolutePath

    actual fun cacheDir(): String =
        AndroidPlatformContext.appContext.cacheDir.absolutePath
}
