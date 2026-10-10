import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/social/presentation/providers/space_providers.dart';
import 'package:smart_calendar_hub/features/social/presentation/widgets/space_drawer.dart';

void main() {
  group('SpaceDrawer Widget Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase testDb;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_space_drawer.db');
      testDb = AppDatabase(connection);
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('SpaceDrawer renders seeded spaces and header', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: Scaffold(
              drawer: SpaceDrawer(userId: 'guest'),
              body: Center(child: Text('Canvas')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Verify header
      expect(find.text('ChronoHub 空間'), findsOneWidget);
      expect(find.text('日曆空間'), findsOneWidget);
      expect(find.text('全選'), findsOneWidget);
      expect(find.text('清空'), findsOneWidget);
      expect(find.text('新增空間'), findsOneWidget);

      // Verify 4 default spaces rendered
      expect(find.text('個人'), findsOneWidget);
      expect(find.text('伴侶'), findsOneWidget);
      expect(find.text('家庭'), findsOneWidget);
      expect(find.text('工作'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Tapping space row activates solo-isolation mode', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late WidgetRef containerRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                containerRef = ref;
                return const Scaffold(
                  drawer: SpaceDrawer(userId: 'guest'),
                  body: Center(child: Text('Canvas')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Tap on "伴侶" row text (not the checkbox)
      await tester.tap(find.text('伴侶'));
      await tester.pumpAndSettle();

      // Only "伴侶" space should be active in solo mode
      final activeIds = containerRef.read(activeSpaceIdsProvider);
      expect(activeIds.length, equals(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Select all and Clear all buttons work correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late WidgetRef containerRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                containerRef = ref;
                return const Scaffold(
                  drawer: SpaceDrawer(userId: 'guest'),
                  body: Center(child: Text('Canvas')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Tap "清空"
      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      expect(containerRef.read(activeSpaceIdsProvider), isEmpty);

      // Tap "全選"
      await tester.tap(find.text('全選'));
      await tester.pumpAndSettle();
      expect(containerRef.read(activeSpaceIdsProvider).length, equals(4));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
