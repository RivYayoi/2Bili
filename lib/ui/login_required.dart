import 'package:flutter/material.dart';

import 'login_page.dart';

class LoginRequiredView extends StatelessWidget {
  const LoginRequiredView({super.key, this.message = '登录后即可查看哔哩哔哩账号数据'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              ),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('扫码登录'),
            ),
          ],
        ),
      ),
    );
  }
}
