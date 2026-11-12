package tv.bili.desktop

import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.okhttp.OkHttp
import org.koin.dsl.module

val desktopModule = module {
    single<HttpClientEngine> { OkHttp.create() }
}
