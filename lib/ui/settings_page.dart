import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/settings_store.dart';
import 'danmaku_settings.dart';
import 'login_page.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final auth = context.watch<AuthController>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _Section(
            title: '外观',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(switch (settings.themeMode) {
                          AppThemeMode.system => Icons.brightness_auto_outlined,
                          AppThemeMode.light => Icons.light_mode_outlined,
                          AppThemeMode.dark => Icons.dark_mode_outlined,
                        }),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('主题')),
                        Text(
                          settings.themeMode.label,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AppThemeMode>(
                        segments: AppThemeMode.values
                            .map(
                              (mode) => ButtonSegment<AppThemeMode>(
                                value: mode,
                                label: Text(mode.label),
                              ),
                            )
                            .toList(),
                        selected: {settings.themeMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          settings.setThemeMode(selection.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: '播放',
            children: [
              ListTile(
                title: const Text('默认画质'),
                subtitle: const Text('打开视频时优先请求的画质'),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: settings.defaultQuality,
                    onChanged: (value) {
                      if (value != null) settings.setDefaultQuality(value);
                    },
                    items: qualityOptions
                        .map(
                          (option) => DropdownMenuItem<int>(
                            value: option.qn,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: '弹幕',
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: DanmakuSettingsControls(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: '账号',
            children: [
              if (auth.isLoggedIn && user != null)
                ListTile(
                  leading: UserAvatar(
                    url: user.faceUrl,
                    name: user.name,
                    size: 40,
                  ),
                  title: Text(user.name),
                  subtitle: Text('UID ${user.mid}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await context.read<AuthController>().logout();
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('已退出登录')));
                      }
                    },
                    child: const Text('退出登录'),
                  ),
                )
              else
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('扫码登录'),
                  subtitle: const Text('登录后可获取更高画质和账号信息'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: '关于',
            children: [
              const ListTile(
                leading: Icon(Icons.play_circle_outline),
                title: Text('2bili'),
                subtitle: Text('版本 2.0.0 · Flutter 重写版'),
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('恢复默认设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  settings.reset();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('已恢复默认设置')));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: biliPink, fontWeight: FontWeight.w600),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
