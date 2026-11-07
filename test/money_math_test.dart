import 'package:flutter_test/flutter_test.dart';
import 'package:moneymesh/domain/money_math.dart';

void main() {
  group('MoneyMath', () {
    test('counts a bank account only once when payment apps link to it twice', () {
      final total = MoneyMath.uniqueAccountBalance([
        (id: 'sbi-2481', balanceMinor: 3275000),
        (id: 'union-7310', balanceMinor: 2550000),
        (id: 'sbi-2481', balanceMinor: 3275000),
      ]);

      expect(total, 5825000);
    });

    test('summarizes income, expenses and net in integer paise', () {
      final summary = MoneyMath.summarize([
        const MoneyEntry(
          title: 'Stipend',
          amountMinor: 500000,
          isIncome: true,
          accountId: 'union-7310',
          category: 'Income',
        ),
        const MoneyEntry(
          title: 'Groceries',
          amountMinor: 125000,
          isIncome: false,
          accountId: 'sbi-2481',
          category: 'Food',
        ),
      ]);

      expect(summary.incomeMinor, 500000);
      expect(summary.expenseMinor, 125000);
      expect(summary.netMinor, 375000);
    });

    test('ignores invalid non-positive entries in summaries', () {
      final summary = MoneyMath.summarize([
        const MoneyEntry(
          title: 'Invalid',
          amountMinor: 0,
          isIncome: true,
          accountId: 'sbi-2481',
          category: 'Other',
        ),
      ]);

      expect(summary.incomeMinor, 0);
      expect(summary.expenseMinor, 0);
    });
  });
}
