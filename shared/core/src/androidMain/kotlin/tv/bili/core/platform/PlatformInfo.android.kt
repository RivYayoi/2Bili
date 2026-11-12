package tv.bili.core.platform

import android.os.Build

actual object PlatformInfo {
    actual val platformName: String = "Android ${Build.VERSION.RELEASE}"
    actual val isDesktop: Boolean = false
}
