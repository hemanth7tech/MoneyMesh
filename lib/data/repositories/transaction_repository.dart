import 'package:sqflite/sqflite.dart';

import '../local/moneymesh_database.dart';

/// Persists transactions using positive integer minor-unit amounts.
class TransactionRepository {
  TransactionRepository({MoneyMeshDatabase? database})
      : _database = database ?? MoneyMeshDatabase.instance;

  final MoneyMeshDatabase _database;

  Future<void> save({
    required String id,
    required String accountId,
    required int amountMinor,
    required String currencyCode,
    required String direction,
    required String description,
    required DateTime occurredAt,
    String? categoryId,
    String? sourcePaymentAppId,
    String? externalReference,
    String? importBatchId,
    String sourceType = 'manual',
  }) async {
    _validate(amountMinor, direction, sourceType, description);
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('transactions', {
      'id': id,
      'financial_account_id': accountId,
      'amount_minor': amountMinor,
      'currency_code': currencyCode,
      'direction': direction,
      'category_id': categoryId,
      'description': description.trim(),
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'source_type': sourceType,
      'source_payment_app_id': sourcePaymentAppId,
      'external_reference': externalReference,
      'import_batch_id': importBatchId,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> update({
    required String id,
    required String accountId,
    required int amountMinor,
    required String currencyCode,
    required String direction,
    required String description,
    required DateTime occurredAt,
    String? categoryId,
    String? sourcePaymentAppId,
  }) async {
    _validate(amountMinor, direction, 'manual', description);
    final db = await _database.database;
    final changed = await db.update(
      'transactions',
      {
        'financial_account_id': accountId,
        'amount_minor': amountMinor,
        'currency_code': currencyCode,
        'direction': direction,
        'category_id': categoryId,
        'description': description.trim(),
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'source_payment_app_id': sourcePaymentAppId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed == 0) throw StateError('Transaction not found.');
  }

  Future<Map<String, Object?>?> getById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getAll({
    String? accountId,
    String? categoryId,
    String? direction,
    String? search,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) async {
    final db = await _database.database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (accountId != null && accountId.isNotEmpty) {
      clauses.add('t.financial_account_id = ?');
      args.add(accountId);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      clauses.add('t.category_id = ?');
      args.add(categoryId);
    }
    if (direction != null && direction.isNotEmpty) {
      clauses.add('t.direction = ?');
      args.add(direction);
    }
    if (search != null && search.trim().isNotEmpty) {
      clauses.add('(t.description LIKE ? OR c.name LIKE ?)');
      args
        ..add('%${search.trim()}%')
        ..add('%${search.trim()}%');
    }
    if (from != null) {
      clauses.add('t.occurred_at >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      clauses.add('t.occurred_at <= ?');
      args.add(to.toUtc().toIso8601String());
    }
    return db.rawQuery('''
      SELECT t.*, a.display_name AS account_name, c.name AS category_name
      FROM transactions t
      LEFT JOIN financial_accounts a ON a.id = t.financial_account_id
      LEFT JOIN categories c ON c.id = t.category_id
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      ORDER BY t.occurred_at DESC
      LIMIT ?
    ''', [...args, limit]);
  }

  Future<bool> isDuplicate({
    required String accountId,
    required int amountMinor,
    required String direction,
    required String description,
    required DateTime occurredAt,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'transactions',
      columns: ['id'],
      where: 'financial_account_id = ? AND amount_minor = ? AND direction = ? AND description = ? AND occurred_at = ?',
      whereArgs: [
        accountId,
        amountMinor,
        direction,
        description.trim(),
        occurredAt.toUtc().toIso8601String(),
      ],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> delete(String id) async {
    final db = await _database.database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  static void _validate(
    int amountMinor,
    String direction,
    String sourceType,
    String description,
  ) {
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor', 'Must be positive');
    }
    if (direction != 'income' && direction != 'expense') {
      throw ArgumentError.value(direction, 'direction', 'Invalid direction');
    }
    if (sourceType != 'manual' && sourceType != 'statement_import') {
      throw ArgumentError.value(sourceType, 'sourceType', 'Invalid source');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError.value(description, 'description', 'Must not be empty');
    }
  }
}
