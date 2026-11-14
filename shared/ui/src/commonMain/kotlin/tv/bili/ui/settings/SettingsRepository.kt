package tv.bili.ui.settings

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.updateAndGet
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okio.FileSystem
import okio.Path.Companion.toPath
import tv.bili.core.platform.FilePathProvider

/**
 * Tiny JSON-backed settings store.
 *
 * The file lives in the platform app-data directory, so desktop keeps it under
 * `~/.2bili/data` and Android keeps it under the app's private files dir.
 */
class SettingsRepository(
    filePathProvider: FilePathProvider,
    private val fileSystem: FileSystem = FileSystem.SYSTEM,
) {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = true
    }
    private val path = filePathProvider.appDataDir().toPath().resolve("settings.json")
    private val _state = MutableStateFlow(load())
    private val writeScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val writeMutex = Mutex()
    private var writeJob: Job? = null

    val state: StateFlow<AppSettings> = _state.asStateFlow()
    val current: AppSettings get() = _state.value

    fun update(transform: (AppSettings) -> AppSettings) {
        val next = _state.updateAndGet(transform)
        // Sliders can emit dozens of values per second; only write the last one.
        writeJob?.cancel()
        writeJob = writeScope.launch {
            delay(200)
            writeMutex.withLock { persist(next) }
        }
    }

    fun reset() = update { AppSettings() }

    private fun load(): AppSettings = runCatching {
        if (!fileSystem.exists(path)) return@runCatching AppSettings()
        json.decodeFromString<AppSettings>(fileSystem.read(path) { readUtf8() })
    }.getOrDefault(AppSettings())

    private fun persist(settings: AppSettings) {
        runCatching {
            val parent = path.parent ?: return@runCatching
            fileSystem.createDirectories(parent)
            fileSystem.write(path) { writeUtf8(json.encodeToString(settings)) }
        }
    }
}
