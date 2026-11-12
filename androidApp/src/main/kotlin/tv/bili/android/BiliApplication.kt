package tv.bili.android

import android.app.Application
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.startKoin
import tv.bili.core.di.coreModule
import tv.bili.core.platform.AndroidPlatformContext
import tv.bili.data.di.dataModule
import tv.bili.ui.di.uiModule

class BiliApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // Must happen before any FilePathProvider / SecureCredentialStore is used.
        AndroidPlatformContext.init(this)

        startKoin {
            androidContext(this@BiliApplication)
            modules(coreModule, dataModule, uiModule, androidModule)
        }
    }
}
