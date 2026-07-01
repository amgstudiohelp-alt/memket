import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ardahan_kulubu/screens/offline_screen.dart';

void main() {
  testWidgets('Offline screen shows connection guidance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OfflineScreen()));

    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.text('İnternet bağlantısı yok'), findsOneWidget);
    expect(find.text('Lütfen bağlantınızı kontrol ediniz.'), findsOneWidget);
  });
}
