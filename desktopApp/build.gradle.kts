import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.gradle.api.tasks.PathSensitivity
import java.io.File

plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.compose.multiplatform)
    alias(libs.plugins.compose.compiler)
}

val appVersion = providers.gradleProperty("app.version").get()

kotlin {
    jvm("desktop") {
        compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
    }

    sourceSets {
        val desktopMain by getting {
            dependencies {
                implementation(project(":shared"))
                implementation(compose.desktop.currentOs)
                implementation(libs.ktor.client.okhttp)
                implementation(libs.koin.core)
                implementation(libs.kotlinx.coroutines.swing)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// VLC bundling
//
// jpackage only bundles the JRE. To make the app image self-contained we stage
// libvlc + plugins into `build/vlc-resources/vlc`, then point the Compose
// plugin's `appResourcesRootDir` at it. The contents end up in the app image's
// `resources/vlc` directory, which VlcSupport checks first.
//
// Source resolution order:
//   1. -PvlcDir=<dir>
//   2. VLC_HOME environment variable
//   3. standard VLC install locations for the current OS
// ---------------------------------------------------------------------------

val vlcSourceProperty = providers.gradleProperty("vlcDir")
    .orElse(providers.environmentVariable("VLC_HOME"))

val skipVlc = providers.gradleProperty("skipVlc")
    .map { it.toBoolean() }
    .orElse(false)

val vlcResourcesDir = layout.buildDirectory.dir("vlc-resources")

val stageVlcResources = tasks.register("stageVlcResources") {
    description = "Stages libvlc and its plugins for bundling into the native app image."
    group = "distribution"

    outputs.dir(vlcResourcesDir)
    outputs.upToDateWhen { false }

    doLast {
        val root = vlcResourcesDir.get().asFile
        root.deleteRecursively()

        // Compose copies `appResourcesRootDir/{common,<os>,<target>}` into the
        // app resources directory. Always create a non-empty `common` so the
        // Sync task runs and removes stale VLC files when bundling is skipped.
        val common = File(root, "common")
        common.mkdirs()
        File(common, ".keep").writeText("")

        if (skipVlc.get()) {
            logger.lifecycle("[2bili] skipVlc=true, not bundling VLC")
            return@doLast
        }

        val explicit = vlcSourceProperty.orNull
            ?.takeIf { it.isNotBlank() }
            ?.let(project::file)

        if (explicit != null && !explicit.isDirectory) {
            throw GradleException("VLC directory does not exist: ${explicit.absolutePath}")
        }

        val source = explicit ?: findVlcDirectory()
        if (source == null) {
            logger.warn(
                "[2bili] VLC not found. The packaged app will require VLC 3.x on the target machine. " +
                    "Install 64-bit VLC, set VLC_HOME, or pass -PvlcDir=<path> to bundle it.",
            )
            return@doLast
        }

        logger.lifecycle("[2bili] Bundling VLC from ${source.absolutePath}")
        val target = File(common, "vlc")
        target.mkdirs()
        copyVlcRuntime(source, target)
    }
}

// `prepareAppResources` copies `appResourcesRootDir/{common,<os>,<target>}`
// into `build/compose/tmp/prepareAppResources`, which the Compose plugin then
// embeds as `app/resources` in every app image and installer.
tasks.matching { it.name == "prepareAppResources" }.configureEach {
    dependsOn(stageVlcResources)
}

// The Compose plugin copies `appResourcesRootDir` into this directory, which
// then becomes the `app/resources` folder inside the app image / installer.
val preparedAppResourcesDir = layout.buildDirectory.dir("compose/tmp/prepareAppResources")

val verifyVlcBundled = tasks.register("verifyVlcBundled") {
    description = "Fails packaging when VLC was requested but could not be staged."
    group = "distribution"

    dependsOn(stageVlcResources)
    dependsOn(tasks.matching { it.name == "prepareAppResources" })
    onlyIf { !skipVlc.get() }

    doLast {
        // This is exactly what the Compose plugin hands to jpackage as
        // `appResourcesDir`, so checking it also covers MSI/EXE installers.
        val vlc = preparedAppResourcesDir.get().asFile.resolve("vlc")
        val hasLibrary = vlc.listFiles()?.any { it.name.startsWith("libvlc") } == true
        val hasPlugins = vlc.resolve("plugins").isDirectory
        if (!hasLibrary || !hasPlugins) {
            throw GradleException(
                "VLC was not bundled into $vlc. Install 64-bit VLC 3.x, set VLC_HOME, " +
                    "or pass -PvlcDir=<path>. Use -PskipVlc=true to build without bundling.",
            )
        }
        logger.lifecycle("[2bili] Verified bundled VLC at ${vlc.absolutePath}")
    }
}

tasks.matching {
    it.name in setOf(
        "createDistributable",
        "createReleaseDistributable",
        "packageMsi",
        "packageExe",
        "packageReleaseMsi",
        "packageReleaseExe",
    )
}.configureEach {
    dependsOn(verifyVlcBundled)
    // `appResourcesDir` is @Internal in the Compose plugin, so changes to the
    // bundled VLC would otherwise leave the packaging task UP-TO-DATE.
    inputs.dir(vlcResourcesDir)
        .withPropertyName("bundledVlc")
        .withPathSensitivity(PathSensitivity.RELATIVE)
}

compose.desktop {
    application {
        mainClass = "tv.bili.desktop.MainKt"

        jvmArgs += listOf("-Dfile.encoding=UTF-8")

        nativeDistributions {
            targetFormats(TargetFormat.Msi, TargetFormat.Exe)
            packageName = "2bili"
            packageVersion = appVersion
            description = "A third-party bilibili client"
            vendor = "2bili"

            // vlcj uses sun.misc.Unsafe (via ByteBufferFactory) to hand the
            // native vmem buffers to Java. jpackage's default module set omits
            // jdk.unsupported, which makes VLC fail with
            // "vmem error: video format setup failure (no pictures)".
            modules("jdk.unsupported")

            windows {
                // jpackage passes --win-shortcut, which creates the desktop
                // shortcut for both per-user and per-machine installs.
                shortcut = true
            }

            appResourcesRootDir.set(vlcResourcesDir)
        }
    }
}

private fun findVlcDirectory(): File? {
    val os = System.getProperty("os.name").orEmpty().lowercase()
    val candidates = buildList {
        when {
            os.contains("win") -> {
                listOfNotNull(
                    System.getenv("ProgramFiles"),
                    System.getenv("ProgramW6432"),
                    System.getenv("ProgramFiles(x86)"),
                ).forEach { add(File(it, "VideoLAN/VLC")) }
                System.getenv("LOCALAPPDATA")?.let { add(File(it, "Programs/VideoLAN/VLC")) }
            }

            os.contains("mac") -> add(File("/Applications/VLC.app/Contents/MacOS/lib"))

            else -> {
                add(File("/usr/lib/x86_64-linux-gnu"))
                add(File("/usr/lib/aarch64-linux-gnu"))
                add(File("/usr/lib64"))
                add(File("/usr/lib"))
                add(File("/usr/local/lib"))
                add(File("/snap/vlc/current/usr/lib"))
                add(File("/snap/vlc/current/usr/lib/x86_64-linux-gnu"))
            }
        }
    }

    return candidates.firstOrNull { dir ->
        dir.isDirectory && dir.list()?.let { names ->
            names.any { it.startsWith("libvlccore.") } && names.any { it.startsWith("libvlc.") }
        } == true
    }
}

private fun copyVlcRuntime(source: File, target: File) {
    val os = System.getProperty("os.name").orEmpty().lowercase()
    val isWindows = os.contains("win")
    val isMac = os.contains("mac")

    if (isWindows) {
        source.listFiles { file -> file.isFile && file.extension.equals("dll", true) }
            ?.forEach { it.copyTo(File(target, it.name), overwrite = true) }
    } else if (isMac) {
        source.listFiles { file -> file.isFile && file.extension == "dylib" }
            ?.forEach { it.copyTo(File(target, it.name), overwrite = true) }
    } else {
        source.listFiles { file ->
            file.isFile && (file.name.startsWith("libvlc.so") || file.name.startsWith("libvlccore.so"))
        }?.forEach { it.copyTo(File(target, it.name), overwrite = true) }
    }

    val plugins = listOf(source.resolve("plugins"), source.resolve("vlc/plugins"))
        .firstOrNull { it.isDirectory }
    plugins?.copyRecursively(File(target, "plugins"), overwrite = true)

    // VLC is GPLv2+/LGPLv2.1+; ship its license files next to the binaries.
    listOf(
        "COPYING", "COPYING.LIB", "AUTHORS",
        "COPYING.txt", "COPYING.LIB.txt", "AUTHORS.txt",
    ).forEach { name ->
        source.resolve(name).takeIf { it.isFile }?.copyTo(File(target, name), overwrite = true)
    }
}
