package tv.bili.core.platform

import android.content.Context

/**
 * Single place where the Android application context is injected.
 * Called once from BiliApplication.onCreate().
 */
object AndroidPlatformContext {
    private var appContextOrNull: Context? = null

    val appContext: Context
        get() = appContextOrNull ?: error("AndroidPlatformContext.init() was not called")

    fun init(context: Context) {
        appContextOrNull = context.applicationContext
    }
}
