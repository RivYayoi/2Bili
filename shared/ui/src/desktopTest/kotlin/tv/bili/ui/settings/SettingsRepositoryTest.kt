package tv.bili.ui.settings

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import tv.bili.core.platform.FilePathProvider
import java.io.File
import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SettingsRepositoryTest {

    @Test
    fun persistsAndReloads() = runBlocking {
        val oldHome = System.getProperty("user.home")
        val temp = Files.createTempDirectory("2bili-settings-test").toFile()
        System.setProperty("user.home", temp.absolutePath)

        try {
            val repository = SettingsRepository(FilePathProvider())
            repository.update {
                it.copy(
                    defaultQuality = 32,
                    danmakuEnabled = false,
                    danmakuOpacity = 0.5f,
                )
            }

            // The repository debounces disk writes by 200 ms.
            delay(800)

            val file = File(temp, ".2bili/data/settings.json")
            assertTrue(file.isFile, "settings file should exist at ${file.absolutePath}")

            val reloaded = SettingsRepository(FilePathProvider())
            assertEquals(32, reloaded.current.defaultQuality)
            assertEquals(false, reloaded.current.danmakuEnabled)
            assertEquals(0.5f, reloaded.current.danmakuOpacity)
        } finally {
            System.setProperty("user.home", oldHome)
            temp.deleteRecursively()
        }
    }
}
