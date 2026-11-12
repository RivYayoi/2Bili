plugins {
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.compose.multiplatform) apply false
    alias(libs.plugins.compose.compiler) apply false
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
}

// Ktor 3.6.x pulls OkHttp 5.5.1, whose AAR requires compileSdk 37 and AGP 9.1.
// Pin to 5.4.0 so the Android build stays on AGP 8.13 / compileSdk 36 while
// keeping the desktop dependency graph unchanged.
allprojects {
    configurations.all {
        resolutionStrategy {
            force("com.squareup.okhttp3:okhttp:5.4.0")
        }
    }
}
