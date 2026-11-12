import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneymesh/main.dart';

void main() {
  testWidgets('dashboard displays core MoneyMesh sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyMeshApp());

    expect(find.text('MoneyMesh'), findsOneWidget);
    expect(find.text('Combined balance'), findsOneWidget);
    expect(find.text('₹58250.00'), findsOneWidget);
    expect(find.text('Bank accounts'), findsOneWidget);
    expect(find.text('Linked payment apps'), findsOneWidget);
    expect(find.text('Recent transactions'), findsOneWidget);
  });

  testWidgets('bottom navigation opens each primary section',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyMeshApp());

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Your recorded activity across linked accounts.'),
        findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('Recorded income'), findsOneWidget);
    expect(find.text('Recorded expenses'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Manage your MoneyMesh preferences.'), findsOneWidget);
  });

  testWidgets('user can add an expense from Activity',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyMeshApp());
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Bus ticket');
    await tester.enterText(find.byType(TextField).at(1), '45');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Bus ticket'), findsOneWidget);
    expect(find.textContaining('₹45'), findsOneWidget);
  });
}
