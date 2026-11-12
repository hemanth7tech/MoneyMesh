import 'package:sqflite/sqflite.dart';

import '../local/moneymesh_database.dart';

class BudgetRepository {
  BudgetRepository({MoneyMeshDatabase? database})
      : _database = database ?? MoneyMeshDatabase.instance;

  final MoneyMeshDatabase _database;

  Future<void> create({
    required String id,
    required int limitMinor,
    required String period,
    required DateTime startDate,
    String? categoryId,
  }) async {
    if (limitMinor <= 0) throw ArgumentError.value(limitMinor, 'limitMinor');
    if (period != 'weekly' && period != 'monthly') {
      throw ArgumentError.value(period, 'period');
    }
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('budgets', {
      'id': id,
      'category_id': categoryId,
      'limit_minor': limitMinor,
      'currency_code': 'INR',
      'period': period,
      'start_date': (period == 'monthly'
              ? DateTime(startDate.year, startDate.month)
              : DateTime(startDate.year, startDate.month, startDate.day))
          .toIso8601String(),
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<Map<String, Object?>>> getActiveWithProgress() async {
    final db = await _database.database;
    final budgets = await db.rawQuery('''
      SELECT b.*, c.name AS category_name
      FROM budgets b
      LEFT JOIN categories c ON c.id = b.category_id
      WHERE b.status = 'active'
      ORDER BY b.created_at DESC
    ''');
    final now = DateTime.now();
    final result = <Map<String, Object?>>[];
    for (final budget in budgets) {
      final start = DateTime.parse(budget['start_date']! as String);
      final end = budget['period'] == 'weekly'
          ? start.add(const Duration(days: 7))
          : DateTime(start.year, start.month + 1, start.day);
      final effectiveEnd = end.isBefore(now) ? end : now;
      final categoryId = budget['category_id'] as String?;
      final rows = await db.rawQuery('''
        SELECT COALESCE(SUM(amount_minor), 0) AS spent_minor
        FROM transactions
        WHERE direction = 'expense'
          AND occurred_at >= ?
          AND occurred_at < ?
          ${categoryId == null ? '' : 'AND category_id = ?'}
      ''', [
        start.toUtc().toIso8601String(),
        effectiveEnd.toUtc().toIso8601String(),
        if (categoryId != null) categoryId,
      ]);
      result.add({
        ...budget,
        'spent_minor': rows.first['spent_minor'] as int,
        'period_end': end.toIso8601String(),
      });
    }
    return result;
  }

  Future<void> archive(String id) async {
    final db = await _database.database;
    await db.update(
      'budgets',
      {
        'status': 'archived',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
