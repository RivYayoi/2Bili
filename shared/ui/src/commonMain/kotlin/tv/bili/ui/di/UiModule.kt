package tv.bili.ui.di

import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module
import tv.bili.ui.screen.detail.VideoDetailViewModel
import tv.bili.ui.screen.home.HomeViewModel
import tv.bili.ui.screen.login.QrLoginViewModel
import tv.bili.ui.screen.player.PlayerViewModel
import tv.bili.ui.screen.search.SearchViewModel
import tv.bili.ui.screen.settings.SettingsViewModel
import tv.bili.ui.settings.SettingsRepository

val uiModule = module {
    single { SettingsRepository(filePathProvider = get()) }
    viewModel { HomeViewModel(repository = get()) }
    viewModel { VideoDetailViewModel(repository = get()) }
    viewModel {
        PlayerViewModel(
            videoRepository = get(),
            danmakuRepository = get(),
            settingsRepository = get(),
        )
    }
    viewModel { SearchViewModel(repository = get()) }
    viewModel { QrLoginViewModel(authRepository = get()) }
    viewModel { SettingsViewModel(repository = get()) }
}
