# 2bili

一个第三方哔哩哔哩客户端脚手架：**Kotlin Multiplatform + Compose Multiplatform**，桌面端（Windows 10+）优先，Android 从第一天起就是可移植目标。

> 仅用于学习 KMP / Compose 桌面开发。请遵守哔哩哔哩用户协议，不要用于商业用途或大规模抓取。

## 已实现（MVP）

- 首页推荐流（下拉/滚动加载更多）
- 视频详情（封面、简介、分 P 列表）；桌面宽屏使用双栏首屏，800×600 下无需滚动即可看到封面、标题和“播放第一页”
- 播放页：DASH 音视频、画质切换、倍速、进度拖动
- 弹幕：历史弹幕 + 实时 WebSocket 弹幕，Compose Canvas 滚动渲染
- 搜索（关键词、分页）
- 扫码登录（二维码生成 + 轮询 + 凭据加密落盘）
- 设置页：默认画质、弹幕开关/不透明度/字号，配置本地持久化
- WBI 签名（`w_rid` + `wts`）统一收口
- 风控处理：`-352` 自动重试一次、`412` 明确报错
- 窗口自适应：800×600 ~ 2560×1440

## 明确不做

直播、番剧、动态、离线缓存、投币/收藏/评论、多账号切换。

## 模块结构

```
:shared                    门面模块（无代码），只做 api 转发
 ├── :shared:core           结果类型、错误、格式化、平台 expect/actual（路径/凭据/平台信息）
 ├── :shared:domain         纯模型 + 仓库接口 + PlayerController 接口（无平台代码）
 ├── :shared:data           Ktor、WBI、风控、DTO、仓库实现、弹幕源
 └── :shared:ui             Compose 主题、导航、页面、ViewModel、播放器 expect/actual
:desktopApp                JVM 入口（Windows 桌面）
:androidApp                Android 入口（仅在检测到 Android SDK 时参与构建）
dist/                      统一产物目录：EXE / MSI / APK（gitignored）
```

依赖方向严格单向：

```
desktopApp / androidApp
        │
        ▼
      :shared
        │
        ├── :shared:ui ──► :shared:domain ──► :shared:core
        └── :shared:data ─► :shared:domain ──► :shared:core
```

- `:shared:ui` **不依赖** `:shared:data`，只面向 domain 接口编程。
- `commonMain` 不出现 `java.*` / `android.*`。
- `expect/actual` 只用于：文件路径、凭据存储、播放器、WebSocket、平台信息。

## 环境要求

| 目标 | 要求 |
| --- | --- |
| 通用 | JDK 17+（推荐 17 或 21） |
| Windows 桌面 | VLC **3.x 64 位**（`vlcj` 需要 `libvlc.dll` / `plugins`） |
| Android | Android SDK Platform 36 + Build-Tools 36.0.0（`ANDROID_HOME` 或 `local.properties` 里的 `sdk.dir`） |

### 关于 VLC

桌面播放器使用 **VLCJ 4.12.1 + CallbackVideoSurface**：

- 视频帧以 `IntArray` 回调，转成 Compose `ImageBitmap` 后由 Compose 直接绘制；
- 弹幕层是普通 Compose 节点，不存在 AWT/Swing 与 Compose 的层级冲突；
- DASH 双流通过 VLC 的 `:input-slave=<audio-url>` 合并播放；
- 画质流优先选 AVC/H.264，其次 HEVC，最后 AV1；杜比视界流会跳过；
- B 站返回的 `backupUrl` 会作为备用 CDN 地址传入播放器，主地址超时/失败时自动切换；HEVC/AV1 会优先使用 `upos-sz` 备用地址，避免主 MCDN 地址握手超时导致长时间黑屏；
- 强制 `--avcodec-hw=none`（软件解码），避免部分 Windows 显卡驱动在 vmem 回调表面下输出黑屏；
- 8 秒内没有收到任何视频帧时，会自动尝试下一个视频地址；音频轨道加载失败时也会尝试下一个音频地址。若所有地址都失败，播放页显示错误而不是一直黑屏。

因此运行时必须能找到 VLC 3.x 的本机库。应用只检查一组固定目录（打包内置的 `resources\vlc`、`VLC_HOME`、`jna.library.path`、`C:\Program Files\VideoLAN\VLC`、`/usr/lib/x86_64-linux-gnu` 等），**不会递归扫描 PATH**——vlcj 默认的发现逻辑会递归遍历 `C:\Windows`，在 WSL 下会卡住启动。若 VLC 装在非标准位置：

```powershell
setx VLC_HOME "D:\Apps\VLC"
# 或
setx VLC_PLUGIN_PATH "D:\Apps\VLC\plugins"
# 或在启动参数里加 -Djna.library.path="D:\Apps\VLC"
```

打包时会把 VLC 一起放进 app image 和 MSI/EXE 安装包（见下一节），目标机器无需再安装。如果 VLC 缺失，应用仍可启动：播放页会显示错误，首页/搜索/登录不受影响。

## 构建与运行

仓库已经包含 Gradle wrapper（`gradlew` / `gradlew.bat` / `gradle-wrapper.jar`），无需本机预装 Gradle。wrapper 默认走华为云镜像下载 Gradle 8.14.3；如需官方源，把 `gradle/wrapper/gradle-wrapper.properties` 里的 `distributionUrl` 换回 `https://services.gradle.org/distributions/gradle-8.14.3-bin.zip`。

```bash
# 桌面端（不需要 Android SDK）
./gradlew :desktopApp:run

# 只编译
./gradlew :desktopApp:compileKotlinDesktop

# 单元测试（WBI 黄金向量、格式化）
./gradlew :shared:data:desktopTest :shared:core:desktopTest
```

Android（需要 SDK）：

```bash
# 确保 ANDROID_HOME 已设置，或创建 local.properties:
# sdk.dir=C\:\\Users\\<you>\\AppData\\Local\\Android\\Sdk
./gradlew :androidApp:assembleDebug
```

最终产物：`dist\2bili-<version>-debug.apk`；中间文件仍在 `androidApp\build\outputs\apk\debug\`。

### 统一产物目录

所有最终产物统一放在仓库根目录的 `dist/`：

| 产物 | 路径 |
| --- | --- |
| Windows EXE 安装包 | `dist\2bili-<version>.exe` |
| Windows MSI 安装包 | `dist\2bili-<version>.msi` |
| Android APK | `dist\2bili-<version>-debug.apk` |

一键构建并收集（Windows 上构建 EXE/MSI，检测到 Android SDK 时同时构建 APK）：

```powershell
.\gradlew.bat packageAll -PvlcDir="C:\Program Files\VideoLAN\VLC"
```

只构建单个目标时，`:desktopApp:packageExe`、`:desktopApp:packageMsi`、`:androidApp:assembleDebug` 也会通过 finalizer 自动把对应产物复制到 `dist/`。`.\gradlew.bat cleanDist` 可清空该目录。构建和产物命名使用的版本号由 `gradle.properties` 的 `app.version` / `app.versionCode` 统一控制（关于页显示文字仍需同步更新）。

`settings.gradle.kts` 会检测 Android SDK；没有 SDK 时 `:androidApp` 不会参与构建，共享模块也不会应用 AGP，因此桌面构建完全不需要 Android 工具链。

> Android 侧当前固定使用 Compose Multiplatform **1.11.1** / AGP **8.13.2** / `compileSdk 36`。Compose 1.12.x 的 Android AAR 要求 AGP 9.1 + `compileSdk 37`，在完成 AGP 9 迁移前不能直接升级。Ktor 3.6.x 传递引入的 OkHttp 5.5.1 同样要求 `compileSdk 37`，根 `build.gradle.kts` 已将其固定到 5.4.0。

### Windows 原生 exe / 安装包

以下任务必须在 **Windows** 上执行（jpackage 不支持跨平台打包）：

```powershell
# 便携版：生成自带 JRE 的 app image，目标机器无需安装 Java
.\gradlew.bat :desktopApp:createDistributable

# 安装包（二选一，需要 WiX Toolset 3.x 在 PATH 中）
.\gradlew.bat :desktopApp:packageMsi
.\gradlew.bat :desktopApp:packageExe

# 构建 EXE + MSI，并自动复制到 dist/
.\gradlew.bat packageAll -PvlcDir="C:\Program Files\VideoLAN\VLC"
```

产物：

| 任务 | 路径 |
| --- | --- |
| `createDistributable` | `desktopApp\build\compose\binaries\main\app\2bili\2bili.exe`（便携版目录，保留为中间产物） |
| `packageMsi` | `dist\2bili-<version>.msi` |
| `packageExe` | `dist\2bili-<version>.exe` |

> `packageExe` / `packageMsi` 现在依赖 `createDistributable`，代码改动后会先刷新 app image，再打安装包。如果仍怀疑缓存，可加 `--rerun-tasks`：
> `.\gradlew.bat :desktopApp:packageExe --rerun-tasks`

便携版直接双击 `2bili.exe` 即可；整个 `2bili` 文件夹可以复制到其他机器。JRE 和 **VLC 都会打包进去**：

- 默认从标准安装路径（`C:\Program Files\VideoLAN\VLC` 等）或 `VLC_HOME` 自动查找；
- 也可以显式指定：`.\gradlew.bat :desktopApp:createDistributable -PvlcDir="D:\Apps\VLC"`；
- VLC 会被放到 app image 的 `resources\vlc`（`libvlc.dll`、`libvlccore.dll`、运行时 DLL、`plugins\`、许可证文件），启动时优先使用它；
- 如果找不到 VLC，打包会失败并提示；确实想生成不带 VLC 的包时加 `-PskipVlc=true`。

`packageMsi` / `packageExe` 生成的安装包也会把 VLC 一起嵌进去；安装后位于 `<安装目录>\app\resources\vlc`，目标机器不需要再单独安装 VLC。安装包体积会相应增加（VLC 的 `plugins\` 占主要部分）。

> VLC 以 GPLv2+/LGPLv2.1+ 分发；打包只是把本机安装的 VLC 文件复制进 app image，仓库本身不包含 VLC 二进制。

### 已生成的 Windows 安装包

| 文件 | 大小 | SHA-256 |
| --- | --- | --- |
| `dist\2bili-1.0.4.exe` | 132 MB | `cd6ef8e4f6259aa146effb22816dedbbe270200d9e32aca28bac100018d5522b` |
| `dist\2bili-1.0.4.msi` | 131 MB | `28bd9f53f64e2a4bc1f72f6ae23924a66aac217834d421d4b4b10f51cb33bdce` |

1.0.4 在 1.0.3 基础上增加设置页、桌面首屏双栏布局，并把版本号递增到 1.0.4，避免覆盖安装时进入同版本维护模式。安装包会创建桌面快捷方式：`desktopApp/build.gradle.kts` 里的 `windows { shortcut = true }` 对应 jpackage 的 `--win-shortcut`，MSI 的 `Shortcut` 表已确认包含 `DesktopFolder | 2bili`。

1.0.3 修复了安装版播放黑屏：jpackage 生成的精简 JRE 默认不含 `jdk.unsupported`，而 vlcj 的 `ByteBufferFactory` 需要 `sun.misc.Unsafe`，缺少时 VLC 会报 `vmem error: video format setup failure (no pictures)`。`desktopApp/build.gradle.kts` 里已显式加入 `modules("jdk.unsupported")`，不要删除。1.0.3 可直接覆盖升级 1.0.0–1.0.2；不要反复运行**同一版本**的安装包，Windows Installer 会进入维护模式，看起来像“没有反应”。

EXE 和 MSI 都是按机器安装（per-machine），安装时会请求管理员权限；未做代码签名，Windows SmartScreen 可能提示“未知发布者”，选择“仍要运行”即可。如果双击后没看到窗口，先检查任务栏里是否有“2bili 安装程序”，也可以右键安装包选择“以管理员身份运行”。

> `dist/`、`build/` 和 `local.properties` 已加入 `.gitignore`，不会提交到 Git；安装包/APK 请按上面的命令在本地生成。

### 已生成的 Android APK

GitHub Release（当前公开附件仍为 1.0.3；1.0.4 本地构建尚未上传）：<https://github.com/RivYayoi/2Bili/releases/tag/v1.0.3>

| 文件 | 大小 | SHA-256 |
| --- | --- | --- |
| `dist\2bili-1.0.4-debug.apk` | 19 MB | `146e45137506ccd4afe1e8c128a1f5d0b673495e6dbd1301267d1a0552ff096d` |

- 包名 `tv.bili.android`，`versionCode 4`，`versionName 1.0.4`
- `minSdk 26` / `targetSdk 36`，包含 `arm64-v8a`、`armeabi-v7a`、`x86`、`x86_64`
- 使用 Android debug keystore 签名，可直接 `adb install`；正式发布前需要配置自己的 release signingConfig
- 安装命令：`adb install -r dist\2bili-1.0.4-debug.apk`

### 验证情况

本项目最终安装包在 Windows 10 + JDK 17 + Gradle 8.14.3 下构建；此前在 Linux + JDK 17 + WSLg 下也验证过窗口启动：

- `./gradlew build` 通过（含全部桌面编译与测试）
- `./gradlew :shared:data:desktopTest :shared:core:desktopTest` 通过（WBI 黄金向量、格式化、播放地址映射共 9 个用例）
- `./gradlew :shared:ui:desktopTest` 通过（含设置本地持久化测试；VLC 测试在没有 `VLC_TEST_*` 环境变量时会自动跳过）
- `./gradlew --version`（wrapper 自举）通过
- `./gradlew :desktopApp:run` 能启动真实窗口（`xwininfo` 可见 `"2bili"`，约 1270×770），主线程进入 Compose 事件循环，首页请求与 LazyGrid 渲染无异常
- 未安装 VLC 时会打印提示，应用继续运行；播放页显示错误而不是崩溃
- 最终 app image（`desktopApp/build/compose/binaries/main/app/2bili/2bili.exe`）在 Windows 上启动成功，窗口标题为 `2bili`
- 1.0.4 MSI 的 `Shortcut` 表已确认包含 `DesktopFolder | 2bili`；实际安装后的桌面快捷方式仍需在干净环境点一次安装验证
- 桌面 800×600 实测：详情页首屏无需滚动即可看到封面、标题和“播放第一页”；首页齿轮可进入设置页
- 1.0.3 EXE 在 Windows 上以管理员权限静默安装成功，覆盖旧 1.0.2；卸载项显示版本 1.0.3，安装目录 `C:\Program Files\2bili`
- 安装后的 1.0.3 已人工点击实测：首页 → 详情 → 播放正常出画，弹幕滚动，音频轨道加载成功（`audioTracks=2`），VLC 日志无 `vmem error`
- 播放页画质菜单可在 480P / 360P 间切换，切换后重新请求播放地址并以 `640x386` 出画；VLC 日志显示 `Received first picture`
- 安装版 runtime 的 `release` 已确认包含 `jdk.unsupported`，这是 1.0.2 黑屏的根因修复
- 对 1.0.3 MSI 做管理安装解包，`runtime\release` 同样包含 `jdk.unsupported`，并确认 VLC 资源已打入包内
- Windows + VLC 3.0.21 下用 VLCJ 集成测试验证过：本地 MP4、B 站 DASH 的 AVC / HEVC / AV1 视频均能收到非空帧；主 CDN 超时后能自动切换到 `upos-sz` 备用地址
- Android `:androidApp:assembleDebug` 构建通过，APK 元数据、四种 ABI 和 debug 签名均已用 `aapt` / `apksigner` 校验
- 当前源码在降低 Android 依赖版本后仍通过桌面编译与共享层测试

未验证项：Android 运行未在真机/模拟器验证（当前 `adb devices` 无设备），因此 ExoPlayer 的 DASH 合并播放和二维码登录需要上机确认；MSI 未单独重复安装（与 EXE 同源），但已用管理安装解包确认运行时模块和 VLC 资源。

### 打包 Windows 安装包

```bash
./gradlew :desktopApp:packageMsi
```

最终产物在 `dist/`；`desktopApp/build/compose/binaries/main/msi/` 只是 jpackage 的中间输出目录。

## 关键设计

### WBI 签名

- `WbiSigner` 是唯一签名入口，仓库层永远不接触 `w_rid`。
- mixin key 表集中在 `MixinKeyTab`。
- `wts` 取 `kotlin.time.Clock.System.now().epochSeconds`。
- nav 接口拿不到 key 时回退到首页 HTML 里的 `wbi/xxx.png`。
- 黄金向量测试：`bar=514&foo=114&wts=1702204169&zab=1919810` →
  `w_rid=8f6f2b5b3d485fe1886cec6a0be8c5d4`。

### 风控

- `-352`：刷新 WBI key + buvid，退避后重试一次。
- `412`：直接返回 `AppError.RiskControl(412)`，UI 提示切换网络/稍后再试。
- 所有 HTTP 都走 `BiliApiClient`，仓库层无重复逻辑。

### 播放器

- 共享层只暴露 `PlayerController` 接口（domain）与两个 expect 函数（ui）：
  `rememberPlayerController()`、`PlatformVideoSurface()`。
- 桌面：`VlcjPlayerController`（回调渲染）。
- Android：`ExoPlayerController`（Media3，`MergingMediaSource` 合并 DASH 音视频）。
- 弹幕时间轴用 `withFrameNanos` 推进，不依赖播放器 4Hz 的回调，画面更顺滑。

### 凭据存储

- Windows：JNA 调 DPAPI（`Crypt32Util`），密文与当前 Windows 用户绑定。
- 非 Windows 开发构建：DPAPI 不可用，自动退回普通 JSON 文件（仅用于本机调试，不要用于生产）。
- Android：Android Keystore AES/GCM，手动实现，不额外引入 `androidx.security`。
- Cookie 只在 `BiliApiClient` 注入。

### 弹幕

当前脚手架为了避开 protobuf 代码生成，采用：

- 历史：`x/v1/dm/list.so`（deflate 压缩的 XML）
- 实时：WebSocket `protover=2`（zlib 压缩的 JSON 帧，二进制包头 + 包体）

服务端始终使用二进制帧（16 字节包头），即使包体是 JSON 也一样；`DanmakuSource` 会拆包、解压并递归处理嵌套帧。生产环境若需要全量弹幕，建议升级为 `protover=3` + protobuf（`bilibili-API-collect` 有 `.proto` 定义）。`DanmakuSource` 是 expect/actual，替换实现不影响 UI。

## 已知限制

- 弹幕轨道分配是轮询，不是严格防重叠；同屏弹幕很多时会叠字。
- 历史弹幕一次性载入，超长视频会占用较多内存。
- 未做播放进度记忆、未做多 P 自动连播。
- 未做评论、点赞、投币、收藏、动态、直播、番剧、离线缓存。
- 未做多账号；切换账号需要清除凭据后重新扫码。
- 二维码状态轮询间隔 2s，登录成功后需要手动返回。
- 桌面端未做全屏切换与快捷键（窗口缩放已适配）。
- 未接入崩溃上报/日志文件。

## 排错

| 现象 | 处理 |
| --- | --- |
| 双击安装包没反应、没有窗口 | 先看任务栏是否有“2bili 安装程序”；安装需要管理员权限，可右键安装包选“以管理员身份运行” |
| 安装包反复运行都停在维护界面 | 不要重复运行同一版本，Windows Installer 会进入维护模式；1.0.4 已递增版本号，可直接覆盖 1.0.3（若仍进入维护模式，先卸载旧版） |
| 播放页黑屏、提示 VLC 初始化失败 | 安装 64 位 VLC 3.x，或设置 `VLC_HOME` / `jna.library.path`；安装包已内置 VLC |
| 播放页黑屏但声音正常 | 已默认软件解码并自动切换备用 CDN；若仍复现，用 `-D2bili.vlc.debug=true` 启动并把控制台 VLC 日志发出来 |
| `./gradlew :desktopApp:run` 能播，安装版黑屏且日志有 `vmem error: video format setup failure (no pictures)` | jpackage 精简 JRE 缺少 `jdk.unsupported`，vlcj 的 `ByteBufferFactory` 初始化 `sun.misc.Unsafe` 失败。确认 `desktopApp/build.gradle.kts` 的 `nativeDistributions { modules("jdk.unsupported") }` 仍在，并重新执行 `packageExe --rerun-tasks` |
| 首页 412 | 触发风控，换网络/等待，或登录后重试 |
| 首页 -352 | 已自动重试一次；仍失败请检查系统时间与网络 |
| 图片不显示 | 检查网络；Coil 已带 Referer/UA，若使用代理请确认代理支持 HTTPS |
| 登录后仍匿名 | 清除 `%APPDATA%/2bili/credentials.bin` 后重新扫码 |

## 目录速查

```
shared/core/src/commonMain/kotlin/tv/bili/core/       AppResult / AppError / Formatters
shared/data/src/commonMain/kotlin/tv/bili/data/wbi/   WBI
shared/data/src/commonMain/kotlin/tv/bili/data/api/   BiliApiClient / HttpClientFactory
shared/ui/src/commonMain/kotlin/tv/bili/ui/screen/    页面与 ViewModel
shared/ui/src/desktopMain/kotlin/tv/bili/ui/player/  VLCJ 实现
shared/ui/src/androidMain/kotlin/tv/bili/ui/player/  Media3 实现
desktopApp/src/desktopMain/kotlin/tv/bili/desktop/   Main.kt / DesktopModule.kt
androidApp/src/main/kotlin/tv/bili/android/          Application / MainActivity
```
