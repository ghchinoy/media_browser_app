// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:media_browser_app/main.dart';

void main() {
  testWidgets('Media Browser app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MediaBrowserApp());

    // Verify that the initial screen has 'Media Browser' title.
    expect(find.text('Media Browser'), findsOneWidget);
    
    // Verify that the 'Select Media Directory' button is present when no directory is selected.
    expect(find.text('Select Media Directory'), findsOneWidget);
  });
}