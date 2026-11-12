package tv.bili.core.platform

import com.sun.jna.platform.win32.Crypt32Util
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Windows DPAPI backed store. The encryption key is bound to the current Windows user,
 * so copying credentials.bin to another machine makes it useless.
 *
 * On non-Windows systems (development builds) DPAPI is unavailable, so the store
 * falls back to a plain JSON file. The Windows build always uses DPAPI.
 */
actual class SecureCredentialStore {

    private val file = File(FilePathProvider().appDataDir(), "credentials.bin")
    private val mutex = Mutex()
    private val json = Json { ignoreUnknownKeys = true }
    private val useDpapi: Boolean =
        System.getProperty("os.name").orEmpty().lowercase().contains("win")

    actual suspend fun put(key: String, value: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            val next = readAll().toMutableMap().apply { this[key] = value }
            writeAll(next)
        }
    }

    actual suspend fun get(key: String): String? = withContext(Dispatchers.IO) {
        mutex.withLock { readAll()[key] }
    }

    actual suspend fun remove(key: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            val next = readAll().toMutableMap().apply { remove(key) }
            writeAll(next)
        }
    }

    actual suspend fun clear() = withContext(Dispatchers.IO) {
        mutex.withLock {
            if (file.exists()) file.delete()
            Unit
        }
    }

    private fun readAll(): Map<String, String> {
        if (!file.isFile) return emptyMap()
        return runCatching {
            val bytes = file.readBytes()
            val plain = if (useDpapi) Crypt32Util.cryptUnprotectData(bytes) else bytes
            json.decodeFromString<Map<String, String>>(plain.decodeToString())
        }.getOrDefault(emptyMap())
    }

    private fun writeAll(values: Map<String, String>) {
        val plain = json.encodeToString(values).encodeToByteArray()
        val encrypted = if (useDpapi) Crypt32Util.cryptProtectData(plain) else plain
        file.parentFile?.mkdirs()
        val tmp = File(file.parentFile, "${file.name}.tmp")
        tmp.writeBytes(encrypted)
        tmp.copyTo(file, overwrite = true)
        tmp.delete()
    }
}
