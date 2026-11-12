package tv.bili.android

import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.okhttp.OkHttp
import org.koin.dsl.module

val androidModule = module {
    single<HttpClientEngine> { OkHttp.create() }
}
