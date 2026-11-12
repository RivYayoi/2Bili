import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.library) apply false
}

/*
 * Facade module: application modules depend on :shared only.
 * It carries no code, it just re-exports the four shared layers so that
 * desktopApp / androidApp never need to know the internal module layout.
 */
val androidEnabled = System.getProperty("bili.android")?.toBoolean() ?: false
if (androidEnabled) apply(plugin = "com.android.library")

kotlin {
    jvm("desktop") {
        compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
    }
    if (androidEnabled) {
        androidTarget {
            compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
        }
    }

    sourceSets {
        commonMain.dependencies {
            api(project(":shared:ui"))
            api(project(":shared:data"))
            api(project(":shared:domain"))
            api(project(":shared:core"))
        }
    }
}

if (androidEnabled) {
    extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
        namespace = "tv.bili.shared"
        compileSdk = 36
        defaultConfig { minSdk = 26 }
        compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }
}
