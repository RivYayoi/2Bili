import org.gradle.api.tasks.Copy
import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.TaskProvider

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

// ---------------------------------------------------------------------------
// Unified distribution directory
//
// Gradle still uses each module's build/ directory for intermediate files, but
// every user-facing artifact is copied into <root>/dist:
//
//   dist/2bili-<version>.exe
//   dist/2bili-<version>.msi
//   dist/2bili-<version>-debug.apk
//
// `packageAll` is the one-shot entry point. The copy tasks are also attached as
// finalizers, so running packageExe/packageMsi/assembleDebug directly still
// leaves the final artifacts in dist/.
// ---------------------------------------------------------------------------

val appVersion = providers.gradleProperty("app.version").get()
val distDir = layout.projectDirectory.dir("dist")
val androidEnabled = System.getProperty("bili.android")?.toBoolean() ?: false

val collectExe = tasks.register<Copy>("collectExe") {
    group = "distribution"
    description = "Builds the Windows EXE installer and copies it into dist/."
    dependsOn(":desktopApp:packageExe")
    from(layout.projectDirectory.dir("desktopApp/build/compose/binaries/main/exe")) {
        include("2bili-$appVersion.exe")
    }
    into(distDir)
}

val collectMsi = tasks.register<Copy>("collectMsi") {
    group = "distribution"
    description = "Builds the Windows MSI installer and copies it into dist/."
    dependsOn(":desktopApp:packageMsi")
    from(layout.projectDirectory.dir("desktopApp/build/compose/binaries/main/msi")) {
        include("2bili-$appVersion.msi")
    }
    into(distDir)
}

val collectApk: TaskProvider<Copy>? = if (androidEnabled) {
    tasks.register<Copy>("collectApk") {
        group = "distribution"
        description = "Builds the Android debug APK and copies it into dist/."
        dependsOn(":androidApp:assembleDebug")
        from(layout.projectDirectory.file("androidApp/build/outputs/apk/debug/androidApp-debug.apk")) {
            rename { "2bili-$appVersion-debug.apk" }
        }
        into(distDir)
    }
} else {
    null
}

val collectArtifacts = tasks.register("collectArtifacts") {
    group = "distribution"
    description = "Builds the Windows installers and Android APK, then copies them into dist/."
    dependsOn(collectExe, collectMsi)
    collectApk?.let { apkTask ->
        dependsOn(apkTask)
    }
}

tasks.register("packageAll") {
    group = "distribution"
    description = "Builds all distributable artifacts and copies them into dist/."
    dependsOn(collectArtifacts)
}

tasks.register<Delete>("cleanDist") {
    group = "distribution"
    description = "Deletes the unified dist/ directory."
    delete(distDir)
}

project(":desktopApp").tasks.matching {
    it.name in setOf("packageExe", "packageMsi")
}.configureEach {
    // packageExe/packageMsi consume the app image produced by
    // createDistributable. The Compose plugin does not declare that edge
    // itself, so without this a code change can be packaged from a stale app
    // image.
    dependsOn(":desktopApp:createDistributable")
}
project(":desktopApp").tasks.matching { it.name == "packageExe" }.configureEach {
    finalizedBy(collectExe)
}
project(":desktopApp").tasks.matching { it.name == "packageMsi" }.configureEach {
    finalizedBy(collectMsi)
}
collectApk?.let { apkTask ->
    project(":androidApp").tasks.matching { it.name == "assembleDebug" }.configureEach {
        finalizedBy(apkTask)
    }
}
