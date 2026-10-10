import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/app/app.dart';

void main() {
  testWidgets('ChronoHub smoke test boots app and verifies guest landing page', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ChronoHubApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ChronoHub Guest Canvas'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
