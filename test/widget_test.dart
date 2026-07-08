import 'package:fieldpilot/app/fieldpilot_app.dart';
import 'package:fieldpilot/core/repositories/providers.dart';
import 'package:fieldpilot/core/services/local_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FieldPilot opens on the dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(MemoryLocalDatabase()),
        ],
        child: const FieldPilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text("Today's visits"), findsOneWidget);
  });
}
