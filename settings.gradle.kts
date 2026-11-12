pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "2bili"

/*
 * Android SDK gate.
 *
 * The desktop app must build and run on a machine that has no Android SDK at all.
 * AGP resolves the SDK during *configuration*, so we do not even include :androidApp
 * (and shared modules do not apply the Android plugin) unless an SDK is detectable.
 */
val hasAndroidSdk = sequenceOf("ANDROID_HOME", "ANDROID_SDK_ROOT")
    .mapNotNull(System::getenv)
    .any { it.isNotBlank() } ||
    rootDir.resolve("local.properties")
        .takeIf { it.isFile }
        ?.readText()
        ?.contains("sdk.dir") == true

System.setProperty("bili.android", hasAndroidSdk.toString())

include(":shared")
include(":shared:core")
include(":shared:domain")
include(":shared:data")
include(":shared:ui")
include(":desktopApp")

if (hasAndroidSdk) {
    include(":androidApp")
} else {
    logger.lifecycle("[2bili] Android SDK not found -> :androidApp excluded (desktop-only build)")
}
