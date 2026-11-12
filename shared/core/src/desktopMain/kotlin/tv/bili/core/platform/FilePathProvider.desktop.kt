package tv.bili.core.platform

import java.io.File

actual class FilePathProvider {
    private val base: File = File(System.getProperty("user.home"), ".2bili")

    actual fun appDataDir(): String = base.resolve("data").apply { mkdirs() }.absolutePath

    actual fun cacheDir(): String = base.resolve("cache").apply { mkdirs() }.absolutePath
}
