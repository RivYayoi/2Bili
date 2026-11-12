package tv.bili.core.platform

expect object PlatformInfo {
    val platformName: String
    val isDesktop: Boolean
}
