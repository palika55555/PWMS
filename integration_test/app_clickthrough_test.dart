import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:problock_pwms/main.dart' as app;
import 'package:problock_pwms/screens/home_screen.dart';

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  // Let the caller fail with a useful expectation.
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PWMS click-through smoke test', (tester) async {
    // Ensure wizard is bypassed and DB path is stable for tests.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('install.completed', true);

    final tmp = await getTemporaryDirectory();
    final dbPath = p.join(tmp.path, 'pwms_integration_test.db');
    try {
      final f = File(dbPath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // ignore
    }
    await prefs.setString('settings.db.filePath', dbPath);

    // Launch the app.
    app.main();
    await tester.pump();
    await _pumpUntilFound(tester, find.byType(HomeScreen));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Home screen sanity.
    expect(find.byType(HomeScreen), findsOneWidget);

    // Open Settings and go back.
    await _tapAndSettle(tester, find.text('Nastavenia'));
    await _tapAndSettle(tester, find.byTooltip('Späť'));

    // Open Transport and go back.
    await _tapAndSettle(tester, find.text('Doprava'));
    await _tapAndSettle(tester, find.byTooltip('Späť'));

    // Open Production and go back.
    await _tapAndSettle(tester, find.text('Výroba'));
    await _tapAndSettle(tester, find.byTooltip('Späť'));

    // Warehouse module.
    await _tapAndSettle(tester, find.text('Skladové hospodárstvo'));

    // Go to Suppliers tab and create supplier (minimal: name only).
    await _tapAndSettle(tester, find.text('Dodávatelia'));
    await _tapAndSettle(tester, find.byType(FloatingActionButton));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Fill required field(s) - relies on label text fallback if no key exists yet.
    final supplierName = find.byKey(const ValueKey('supplier.name'));
    if (supplierName.evaluate().isNotEmpty) {
      await tester.enterText(supplierName, 'Test Dodávateľ');
    } else {
      await tester.enterText(find.text('Názov dodávateľa'), 'Test Dodávateľ');
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final supplierSave = find.byKey(const ValueKey('supplier.save'));
    if (supplierSave.evaluate().isNotEmpty) {
      await _tapAndSettle(tester, supplierSave);
    } else {
      // fallback: find a save button by text
      await _tapAndSettle(tester, find.textContaining('Uložiť'));
    }

    // Customers tab: create customer (minimal: name only).
    await _tapAndSettle(tester, find.text('Zákazníci'));
    await _tapAndSettle(tester, find.byType(FloatingActionButton));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final customerName = find.byKey(const ValueKey('customer.name'));
    if (customerName.evaluate().isNotEmpty) {
      await tester.enterText(customerName, 'Test Zákazník');
    } else {
      await tester.enterText(find.text('Názov zákazníka'), 'Test Zákazník');
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final customerSave = find.byKey(const ValueKey('customer.save'));
    if (customerSave.evaluate().isNotEmpty) {
      await _tapAndSettle(tester, customerSave);
    } else {
      await _tapAndSettle(tester, find.textContaining('Uložiť'));
    }

    // Approvals screen open.
    await _tapAndSettle(tester, find.text('Na schválenie'));

    // Back to Home.
    await _tapAndSettle(tester, find.byTooltip('Späť'));
  });
}


