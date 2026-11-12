package tv.bili.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import androidx.navigation.compose.rememberNavController
import coil3.ImageLoader
import coil3.compose.setSingletonImageLoaderFactory
import coil3.network.ktor3.KtorNetworkFetcherFactory
import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.request.header
import io.ktor.http.HttpHeaders
import org.koin.compose.koinInject
import tv.bili.ui.navigation.AppNavHost
import tv.bili.ui.theme.BiliTheme

private const val IMAGE_UA =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

/**
 * The single shared UI entry point.
 *
 * It deliberately takes no WindowState / Context / Activity parameter:
 * everything platform-specific is resolved through Koin or expect/actual.
 */
@Composable
fun App() {
    val engine = koinInject<HttpClientEngine>()

    // bilibili's image CDN rejects requests without a Referer, so the image
    // client is configured here once, in commonMain, for both platforms.
    setSingletonImageLoaderFactory { context ->
        ImageLoader.Builder(context)
            .components {
                add(
                    KtorNetworkFetcherFactory(
                        httpClient = {
                            HttpClient(engine) {
                                defaultRequest {
                                    header(HttpHeaders.Referrer, "https://www.bilibili.com")
                                    header(HttpHeaders.UserAgent, IMAGE_UA)
                                }
                            }
                        },
                    ),
                )
            }
            .build()
    }

    ProvideViewModelStoreOwner {
        BiliTheme {
            val navController = rememberNavController()
            AppNavHost(navController = navController)
        }
    }
}

/**
 * Compose Desktop does not always install a LocalViewModelStoreOwner.
 * On Android this is a no-op because the Activity already provides one.
 */
@Composable
private fun ProvideViewModelStoreOwner(content: @Composable () -> Unit) {
    val current = LocalViewModelStoreOwner.current
    if (current != null) {
        content()
        return
    }

    val owner = remember {
        object : ViewModelStoreOwner {
            override val viewModelStore: ViewModelStore = ViewModelStore()
        }
    }

    CompositionLocalProvider(LocalViewModelStoreOwner provides owner, content = content)
}
