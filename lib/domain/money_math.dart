/// Core money calculations used by MoneyMesh.
class MoneySummary {
  const MoneySummary({
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}

/// Amounts are stored as integer paise to avoid floating-point money errors.
class MoneyEntry {
  const MoneyEntry({
    required this.title,
    required this.amountMinor,
    required this.isIncome,
    required this.accountId,
    required this.category,
  });

  final String title;
  final int amountMinor;
  final bool isIncome;
  final String accountId;
  final String category;
}

class MoneyMath {
  const MoneyMath._();

  static int uniqueAccountBalance(Iterable<({String id, int balanceMinor})> accounts) {
    final seen = <String>{};
    var total = 0;
    for (final account in accounts) {
      if (seen.add(account.id)) total += account.balanceMinor;
    }
    return total;
  }

  static MoneySummary summarize(Iterable<MoneyEntry> entries) {
    var income = 0;
    var expenses = 0;
    for (final entry in entries) {
      if (entry.amountMinor <= 0) continue;
      if (entry.isIncome) {
        income += entry.amountMinor;
      } else {
        expenses += entry.amountMinor;
      }
    }
    return MoneySummary(incomeMinor: income, expenseMinor: expenses);
  }
}
