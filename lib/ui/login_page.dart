import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/auth_controller.dart';
import '../core/bili_api.dart';
import '../core/models.dart';
import 'theme.dart';
import 'widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _qrUrl;
  QrStatus _status = QrStatus.waiting;
  String _message = '';
  Object? _error;
  bool _starting = false;
  bool _finished = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    if (!auth.isLoggedIn) {
      _startQr();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _startQr() async {
    if (_starting) return;
    final generation = ++_generation;
    setState(() {
      _starting = true;
      _error = null;
      _qrUrl = null;
      _status = QrStatus.waiting;
      _message = '正在获取二维码…';
    });
    try {
      final ticket = await context.read<BiliApi>().generateQr();
      if (!mounted || generation != _generation) return;
      setState(() {
        _qrUrl = ticket.url;
        _starting = false;
        _message = '请使用哔哩哔哩客户端扫码';
      });
      _poll(ticket.key, generation);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _starting = false;
        _error = error;
        _message = '二维码获取失败';
      });
    }
  }

  Future<void> _poll(String key, int generation) async {
    while (mounted && generation == _generation) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || generation != _generation) return;
      try {
        final poll = await context.read<BiliApi>().pollQr(key);
        if (!mounted || generation != _generation) return;
        setState(() {
          _status = poll.status;
          _error = null;
          _message = switch (poll.status) {
            QrStatus.waiting => '等待扫码',
            QrStatus.scanned => '已扫码，请在手机上确认登录',
            QrStatus.expired => '二维码已过期，请刷新',
            QrStatus.success => '登录成功',
          };
        });
        if (poll.status == QrStatus.success) {
          final credential = poll.credential;
          if (credential == null) {
            throw const BiliException(-1, '登录凭据无效');
          }
          await context.read<AuthController>().completeLogin(credential);
          if (!mounted || generation != _generation) return;
          setState(() => _finished = true);
          await Future<void>.delayed(const Duration(milliseconds: 700));
          if (mounted) Navigator.of(context).pop();
          return;
        }
        if (poll.status == QrStatus.expired) return;
      } catch (error) {
        if (!mounted || generation != _generation) return;
        setState(() => _error = error);
      }
    }
  }

  Future<void> _logout() async {
    await context.read<AuthController>().logout();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final showAccount = auth.isLoggedIn && _qrUrl == null && !_starting;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('扫码登录'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: showAccount
              ? _accountView(auth, user)
              : _qrView(context),
        ),
      ),
    );
  }

  Widget _accountView(AuthController auth, BiliUser? user) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(
          url: user?.faceUrl ?? '',
          name: user?.name ?? '已登录',
          size: 88,
        ),
        const SizedBox(height: 16),
        Text(
          user?.name ?? '已登录',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          user != null ? 'UID ${user.mid}' : '登录凭据已保存',
          style: const TextStyle(color: appMuted, fontSize: 12),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('返回'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _logout,
          child: const Text('退出登录'),
        ),
        TextButton(
          onPressed: _startQr,
          child: const Text('切换账号'),
        ),
      ],
    );
  }

  Widget _qrView(BuildContext context) {
    final statusColor = switch (_status) {
      QrStatus.success => const Color(0xFF4CAF50),
      QrStatus.scanned => biliBlue,
      QrStatus.expired => const Color(0xFFFF6B6B),
      QrStatus.waiting => appMuted,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 300,
          height: 300,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _qrUrl == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Color(0xFFFF6B6B),
                        ),
                )
              : QrImageView(
                  data: _qrUrl!,
                  size: 264,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
        ),
        const SizedBox(height: 18),
        Text(
          _finished ? '登录成功' : _message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: statusColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            userMessageFor(_error!),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: _starting ? null : _startQr,
              child: const Text('刷新二维码'),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '扫码后请在手机上点击确认',
          style: TextStyle(color: appMuted, fontSize: 12),
        ),
      ],
    );
  }
}
