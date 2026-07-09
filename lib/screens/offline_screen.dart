import 'dart:async';

import 'package:flutter/material.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, this.onRetry});

  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              '\u0130nternet ba\u011flant\u0131s\u0131 yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'L\u00fctfen ba\u011flant\u0131n\u0131z\u0131 kontrol ediniz.',
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry == null ? null : () => unawaited(onRetry!()),
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
