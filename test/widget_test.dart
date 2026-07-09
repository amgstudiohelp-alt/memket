import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ardahan_kulubu/screens/offline_screen.dart';

void main() {
  testWidgets('Offline screen shows connection guidance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OfflineScreen()));

    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(
      find.text('\u0130nternet ba\u011flant\u0131s\u0131 yok'),
      findsOneWidget,
    );
    expect(
      find.text('L\u00fctfen ba\u011flant\u0131n\u0131z\u0131 kontrol ediniz.'),
      findsOneWidget,
    );
    expect(find.text('Tekrar dene'), findsOneWidget);
  });
}
