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
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor', 'Must be positive');
    }
    if (direction != 'income' && direction != 'expense') {
      throw ArgumentError.value(direction, 'direction', 'Invalid direction');
    }
    if (sourceType != 'manual' && sourceType != 'statement_import') {
      throw ArgumentError.value(sourceType, 'sourceType', 'Invalid source');
    }
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

  Future<List<Map<String, Object?>>> getAll({
    String? accountId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _database.database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (accountId != null) {
      clauses.add('financial_account_id = ?');
      args.add(accountId);
    }
    if (from != null) {
      clauses.add('occurred_at >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      clauses.add('occurred_at <= ?');
      args.add(to.toUtc().toIso8601String());
    }
    return db.query(
      'transactions',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'occurred_at DESC',
    );
  }

  Future<int> delete(String id) async {
    final db = await _database.database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}
