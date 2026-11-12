package tv.bili.data.di

import org.koin.dsl.module
import tv.bili.data.api.BiliApiClient
import tv.bili.data.api.createBiliHttpClient
import tv.bili.data.auth.BuvidManager
import tv.bili.data.auth.CookieProvider
import tv.bili.data.auth.CredentialRepository
import tv.bili.data.auth.QrLoginApi
import tv.bili.data.danmaku.DanmakuSource
import tv.bili.data.repository.AuthRepositoryImpl
import tv.bili.data.repository.DanmakuRepositoryImpl
import tv.bili.data.repository.SearchRepositoryImpl
import tv.bili.data.repository.VideoRepositoryImpl
import tv.bili.data.risk.RiskControlHandler
import tv.bili.data.wbi.DefaultWbiSigner
import tv.bili.data.wbi.NavWbiKeyProvider
import tv.bili.data.wbi.WbiKeyProvider
import tv.bili.data.wbi.WbiSigner
import tv.bili.domain.repository.AuthRepository
import tv.bili.domain.repository.DanmakuRepository
import tv.bili.domain.repository.SearchRepository
import tv.bili.domain.repository.VideoRepository

val dataModule = module {
    single { createBiliHttpClient(get()) }

    single { BuvidManager(engine = get(), store = get()) }
    single { CredentialRepository(store = get(), buvid = get()) }
    single<CookieProvider> { get<CredentialRepository>() }
    single { NavWbiKeyProvider(http = get()) }

    single<WbiKeyProvider> { get<NavWbiKeyProvider>() }
    single<WbiSigner> { DefaultWbiSigner(keys = get()) }
    single { RiskControlHandler(buvid = get()) }

    single { BiliApiClient(http = get(), signer = get(), risk = get(), cookies = get()) }
    single { QrLoginApi(http = get()) }

    single<VideoRepository> { VideoRepositoryImpl(api = get()) }
    single<SearchRepository> { SearchRepositoryImpl(api = get()) }
    single<AuthRepository> { AuthRepositoryImpl(api = get(), qrLoginApi = get(), credentials = get()) }

    single { DanmakuSource() }
    single<DanmakuRepository> { DanmakuRepositoryImpl(source = get()) }
}
