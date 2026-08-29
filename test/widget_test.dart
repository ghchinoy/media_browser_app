import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_browser_app/main.dart';

void main() {
  testWidgets('Media Browser app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MediaBrowserApp());

    expect(find.text('Media Browser'), findsWidgets);
    expect(find.text('Select Media Directory (Cmd+O)'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsWidgets);
  });

  testWidgets('MediaHomePage toggles theme mode', (WidgetTester tester) async {
    await tester.pumpWidget(const MediaBrowserApp());

    final themeButton = find.byTooltip('Toggle Theme');
    expect(themeButton, findsOneWidget);

    await tester.tap(themeButton);
    await tester.pump();
  });
}