package tv.bili.ui.player

import java.io.File
import java.text.SimpleDateFormat
import java.util.Date

/**
 * Diagnostic log for the desktop player.
 *
 * The packaged Windows launcher is a GUI process, so `System.err` is not
 * visible when the user double-clicks the app. Keeping a small file log makes
 * it possible to diagnose black-screen / CDN failures on a real machine.
 */
internal object PlayerDebugLog {

    private val directory: File = File(
        System.getenv("LOCALAPPDATA") ?: System.getProperty("user.home"),
        "2bili",
    )

    val playerLogFile: File = File(directory, "player.log")
    val vlcLogFile: File = File(directory, "vlc.log")

    private val timeFormat = SimpleDateFormat("HH:mm:ss.SSS")

    init {
        runCatching {
            directory.mkdirs()
            playerLogFile.writeText("")
            vlcLogFile.delete()
        }
    }

    @Synchronized
    fun log(message: String) {
        val line = "${timeFormat.format(Date())} $message"
        System.err.println("[2bili] $line")
        runCatching { playerLogFile.appendText(line + "\n") }
    }
}
