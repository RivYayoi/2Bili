package tv.bili.desktop

import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import org.koin.core.context.startKoin
import tv.bili.core.di.coreModule
import tv.bili.data.di.dataModule
import tv.bili.ui.App
import tv.bili.ui.di.uiModule
import tv.bili.ui.player.VlcSupport
import java.awt.Dimension

fun main() {
    // VLCJ needs the VLC natives before any MediaPlayerFactory is constructed.
    // VlcSupport uses a bounded, non-recursive search instead of vlcj's default
    // discovery, which would recursively walk every PATH entry (e.g. C:\Windows).
    // A failed discovery is not fatal: the UI shows a player error and the rest
    // of the app (home / search / login) keeps working.
    val vlcFound = VlcSupport.discover()
    if (!vlcFound) {
        System.err.println("[2bili] ${VlcSupport.installHint()}")
    }

    startKoin {
        modules(coreModule, dataModule, uiModule, desktopModule)
    }

    application {
        val windowState = rememberWindowState(width = 1280.dp, height = 800.dp)

        Window(
            onCloseRequest = ::exitApplication,
            state = windowState,
            title = "2bili",
        ) {
            LaunchedEffect(Unit) {
                window.minimumSize = Dimension(800, 600)
            }
            App()
        }
    }
}
