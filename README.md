# 2bili

2bili 是哔哩哔哩的第三方桌面 / Android 客户端。当前分支已从 Kotlin Multiplatform + Compose 全量重写为 Flutter，播放器使用 `media_kit` + `libmpv`。

## 功能

- 首页推荐流，接口失败时自动回退到热门列表，支持无限滚动与下拉刷新。
- 视频搜索，支持分页加载。
- 视频详情、分P 列表、简介、UP 主信息。
- 播放器：播放 / 暂停、进度拖动、倍速、画质切换、错误重试。
- 弹幕：历史弹幕 XML、WebSocket 实时弹幕、透明度与字号设置。
- 评论：热门 / 最新排序，主评论游标分页，楼中楼回复分页（只读）。
- 扫码登录、登录状态展示、退出登录。
- 深色 Bilibili 主题，桌面窗口最小 800×600。

## 技术栈

- Flutter 3.50 stable / Dart 3.14
- `media_kit`、`media_kit_video`、`media_kit_libs_video`（libmpv）
- `provider`、`http`、`shared_preferences`、`flutter_secure_storage`
- `qr_flutter`、`cached_network_image`、`window_manager`

## 播放策略

播放地址优先请求 `fnval=0` 的 progressive MP4，匿名状态下通常可以直接获得 720P。若接口只返回 DASH，则回退到 `fnval=4048`，通过 libmpv 的 `audio-add` 附加独立音轨。播放请求会携带 Bilibili 要求的 `Referer` 与 `User-Agent`。

## 构建

### Windows

需要 Flutter 3.50+、Visual Studio 2022（Desktop development with C++）和 Windows 10+。

```powershell
flutter pub get
flutter build windows --release
```

产物位于 `build/windows/x64/runner/Release/`，其中已包含 `libmpv-2.dll`、ANGLE 和 Flutter 运行库。

Flutter 在 Windows 上构建插件时需要创建符号链接。若出现 “Building with plugins requires symlink support”，请在 Windows 设置中开启开发者模式：

```powershell
start ms-settings:developers
```

### Android

需要 JDK 17、Android SDK（compileSdk 36）和 Flutter 3.50+。

```powershell
$env:JAVA_HOME = "C:\path\to\jdk17"
flutter build apk --release
```

产物位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 发布产物

构建完成后，将 Windows Release 目录和 Android APK 统一复制到根目录 `dist/`。`dist/` 已被 `.gitignore` 忽略。

## 说明

- 本项目仅用于学习与个人使用，请遵守哔哩哔哩的用户协议。
- 评论区目前只读，不包含发布评论 / 回复功能。
- 登录凭据保存在系统安全存储中；桌面端使用 Windows Credential Manager，Android 端使用 Keystore。
