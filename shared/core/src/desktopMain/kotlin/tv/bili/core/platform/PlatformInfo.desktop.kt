package tv.bili.core.platform

actual object PlatformInfo {
    actual val platformName: String = System.getProperty("os.name") ?: "Desktop"
    actual val isDesktop: Boolean = true
}
