package tv.bili.core.di

import org.koin.dsl.module
import tv.bili.core.platform.FilePathProvider
import tv.bili.core.platform.SecureCredentialStore

val coreModule = module {
    single { FilePathProvider() }
    single { SecureCredentialStore() }
}
