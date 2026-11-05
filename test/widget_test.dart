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
}
