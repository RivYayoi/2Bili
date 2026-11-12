package tv.bili.ui.player

import com.sun.jna.NativeLibrary
import uk.co.caprica.vlcj.binding.lib.LibC
import uk.co.caprica.vlcj.binding.support.runtime.RuntimeUtil
import uk.co.caprica.vlcj.factory.discovery.NativeDiscovery
import uk.co.caprica.vlcj.factory.discovery.strategy.NativeDiscoveryStrategy
import java.io.File

/**
 * Bounded VLC native discovery.
 *
 * vlcj's default [NativeDiscovery] walks *every* `PATH` entry recursively.
 * On Windows that descends into `C:\Windows`, and under WSL into
 * `/mnt/c/Windows`, which can block the main thread for minutes when VLC is
 * not installed. This locator only probes a handful of well-known install
 * directories, one level deep, so startup stays fast either way.
 *
 * [discovery] is also handed to `MediaPlayerFactory`; otherwise the factory
 * would build its own default discovery and scan `PATH` again.
 */
object VlcSupport {

    private val osName: String = System.getProperty("os.name").orEmpty().lowercase()
    private val isWindows: Boolean = osName.contains("win")
    private val isMac: Boolean = osName.contains("mac")

    private val nativeDiscovery: NativeDiscovery by lazy {
        NativeDiscovery(BoundedDiscoveryStrategy())
    }

    /**
     * Locate libvlc and register its directory with JNA.
     *
     * @return `true` when libvlc was found and loaded.
     */
    fun discover(): Boolean = runCatching { nativeDiscovery.discover() }.getOrDefault(false)

    /**
     * Discovery instance that never scans `PATH`.
     *
     * Pass it to `MediaPlayerFactory(discovery, *args)` so the factory does not
     * fall back to vlcj's recursive default discovery.
     */
    fun discovery(): NativeDiscovery = nativeDiscovery

    fun installHint(): String = if (isWindows) {
        "未找到 VLC。请安装 64 位 VLC 3.x（https://www.videolan.org/），" +
            "或把 VLC 目录加入 PATH / 设置 VLC_HOME。"
    } else {
        "未找到 VLC。请安装 VLC 3.x（libvlc），" +
            "或设置 VLC_HOME 指向包含 libvlc 的目录。"
    }

    private class BoundedDiscoveryStrategy : NativeDiscoveryStrategy {

        override fun supported(): Boolean = true

        override fun discover(): String? {
            val found = candidateDirectories().firstOrNull(::containsVlcLibraries)?.absolutePath
            PlayerDebugLog.log("VLC discovery found=$found")
            return found
        }

        override fun onFound(path: String): Boolean = runCatching {
            PlayerDebugLog.log("VLC onFound path=$path")
            NativeLibrary.addSearchPath(RuntimeUtil.getLibVlcCoreLibraryName(), path)
            NativeLibrary.getInstance(RuntimeUtil.getLibVlcCoreLibraryName())
            true
        }.getOrDefault(false)

        override fun onSetPluginPath(path: String): Boolean {
            val plugins = File(path, "plugins").takeIf(File::isDirectory)
                ?: File(File(path, "vlc"), "plugins").takeIf(File::isDirectory)
                ?: return false
            PlayerDebugLog.log("VLC plugin path=$plugins")
            return runCatching {
                val result = if (isWindows) {
                    LibC.INSTANCE._putenv("VLC_PLUGIN_PATH=${plugins.absolutePath}")
                } else {
                    LibC.INSTANCE.setenv("VLC_PLUGIN_PATH", plugins.absolutePath, 1)
                }
                result == 0
            }.getOrDefault(false)
        }
    }

    /**
     * Directories that are actually checked, in priority order.
     *
     * `PATH` is deliberately excluded: a single non-recursive listing of
     * `C:\Windows\System32` is usually fine, but on WSL's DrvFs it is already
     * noticeably slow, and custom installs are covered by `VLC_HOME`.
     */
    private fun candidateDirectories(): List<File> {
        val dirs = LinkedHashSet<File>()

        fun add(path: String?) {
            if (!path.isNullOrBlank()) {
                dirs.add(File(path))
            }
        }

        // Bundled VLC: jpackage sets this to <app-image>/app/resources
        // (Windows) or <app-image>/lib/app/resources (Linux/macOS).
        System.getProperty("compose.application.resources.dir")
            ?.let { add(File(it, "vlc").path) }

        add(System.getenv("VLC_HOME"))
        System.getProperty("jna.library.path")
            ?.split(File.pathSeparator)
            ?.forEach(::add)

        // Portable app-image layout: a `vlc` folder next to 2bili.exe (or inside
        // the app image), so the whole directory can be copied to another PC.
        System.getProperty("jpackage.app-path")
            ?.let { File(it).parentFile }
            ?.let { base ->
                add(File(base, "vlc").path)
                add(File(base, "app/vlc").path)
                add(File(base, "app/resources/vlc").path)
                add(File(base, "lib/app/resources/vlc").path)
            }

        if (isWindows) {
            val programFiles = System.getenv("ProgramFiles")
            val programFilesX86 = System.getenv("ProgramFiles(x86)")
            val programW6432 = System.getenv("ProgramW6432")
            for (base in listOfNotNull(programFiles, programW6432, programFilesX86)) {
                add("$base\\VideoLAN\\VLC")
            }
            System.getenv("LOCALAPPDATA")?.let { add("$it\\Programs\\VideoLAN\\VLC") }
        } else if (isMac) {
            add("/Applications/VLC.app/Contents/MacOS/lib")
        } else {
            add("/usr/lib/x86_64-linux-gnu")
            add("/usr/lib/aarch64-linux-gnu")
            add("/usr/lib64")
            add("/usr/lib")
            add("/usr/local/lib")
            add("/snap/vlc/current/usr/lib")
            add("/snap/vlc/current/usr/lib/x86_64-linux-gnu")
        }

        return dirs.toList()
    }

    private fun containsVlcLibraries(dir: File): Boolean {
        if (!dir.isDirectory) return false
        val names = dir.list() ?: return false
        var hasCore = false
        var hasLib = false
        for (name in names) {
            when {
                name.startsWith("libvlccore.") -> hasCore = true
                name.startsWith("libvlc.") -> hasLib = true
            }
            if (hasCore && hasLib) return true
        }
        return false
    }
}
