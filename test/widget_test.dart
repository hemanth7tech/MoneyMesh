import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:moneymesh/data/local/moneymesh_database.dart';
import 'package:moneymesh/main.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const MoneyMeshApp());
  await waitForDatabase(tester);
}

Future<void> waitForDatabase(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    ffi.sqfliteFfiInit();
    sqflite.databaseFactory = ffi.databaseFactoryFfiNoIsolate;
    final path = '${await sqflite.getDatabasesPath()}/moneymesh.db';
    await sqflite.deleteDatabase(path);
  });

  tearDownAll(() async {
    await MoneyMeshDatabase.instance.close();
  });

  testWidgets('dashboard shows empty local account and transaction sections',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('MoneyMesh'), findsOneWidget);
    expect(find.text('Combined balance'), findsOneWidget);
    expect(find.text('₹0.00'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Bank accounts'), 250);
    expect(find.text('Bank accounts'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Linked payment apps'), 250);
    expect(find.text('Linked payment apps'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Recent transactions'), 300);
    expect(find.text('Recent transactions'), findsOneWidget);
  });

  testWidgets('bottom navigation opens activity, insights and settings',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.text('Your recorded activity across linked accounts.'),
        findsOneWidget);

    await tester.tap(find.text('Insights').last);
    await tester.pumpAndSettle();
    expect(find.text('Recorded income'), findsOneWidget);
    expect(find.text('Recorded expenses'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Manage your MoneyMesh preferences.'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
  });

  testWidgets('account and transaction persist and update derived balance',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();

    final accountFields = find.byType(TextField);
    await tester.enterText(accountFields.at(0), 'State Bank of India');
    await tester.enterText(accountFields.at(1), 'SBI Main');
    await tester.enterText(accountFields.at(2), '•••• 2481');
    await tester.enterText(accountFields.at(3), '1000.00');
    await tester.tap(find.text('Save account'));
    await waitForDatabase(tester);

    expect(find.text('SBI Main'), findsOneWidget);
    expect(find.text('₹1000.00'), findsOneWidget);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Bus ticket');
    await tester.enterText(fields.at(1), '45.00');

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save').last);
    await waitForDatabase(tester);

    expect(find.text('Bus ticket'), findsOneWidget);
    expect(find.textContaining('₹45.00'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh data'));
    await waitForDatabase(tester);

    expect(find.text('₹955.00'), findsOneWidget);
    expect(find.text('Bus ticket'), findsOneWidget);
  });
}
