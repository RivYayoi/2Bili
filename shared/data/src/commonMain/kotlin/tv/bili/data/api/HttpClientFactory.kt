package tv.bili.data.api

import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.request.header
import io.ktor.client.request.url
import io.ktor.http.HttpHeaders
import io.ktor.serialization.kotlinx.json.json

fun createBiliHttpClient(engine: HttpClientEngine): HttpClient = HttpClient(engine) {
    expectSuccess = false

    install(ContentNegotiation) {
        json(BiliJson)
    }

    install(HttpTimeout) {
        requestTimeoutMillis = 20_000
        connectTimeoutMillis = 10_000
        socketTimeoutMillis = 20_000
    }

    defaultRequest {
        url("https://api.bilibili.com")
        header(HttpHeaders.Referrer, BiliHeaders.REFERER)
        header(HttpHeaders.UserAgent, BiliHeaders.UA)
        header(HttpHeaders.Origin, BiliHeaders.ORIGIN)
    }
}
