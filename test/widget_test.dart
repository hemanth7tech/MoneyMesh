import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moneymesh/main.dart';

void main() {
  testWidgets('app shell navigates through the main finance sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyMeshApp(loadDataOnStart: false));
    await tester.pumpAndSettle();

    expect(find.text('MoneyMesh'), findsOneWidget);
    expect(find.text('Loading your local finance data…'), findsOneWidget);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Date range'), findsOneWidget);

    await tester.tap(find.text('Insights').last);
    await tester.pumpAndSettle();
    expect(find.text('Recorded income'), findsOneWidget);
    expect(find.text('Recorded expenses'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Export local data'), findsOneWidget);
    expect(find.text('Delete all local data'), findsOneWidget);
  });

  testWidgets('account form opens and transaction entry requires an account',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyMeshApp(loadDataOnStart: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();

    expect(find.text('Add bank account'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      findsNWidgets(4),
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(
      find.text('Add a bank account before recording transactions.'),
      findsOneWidget,
    );
  });
}
