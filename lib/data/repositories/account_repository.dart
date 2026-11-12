import 'package:sqflite/sqflite.dart';

import '../local/moneymesh_database.dart';

/// Account metadata. Balances are derived from opening balance plus ledger entries.
class AccountRecord {
  const AccountRecord({
    required this.id,
    required this.institutionName,
    required this.displayName,
    required this.currencyCode,
    required this.openingBalanceMinor,
    required this.currentBalanceMinor,
    this.maskedAccountReference,
    this.status = 'active',
  });

  final String id;
  final String institutionName;
  final String displayName;
  final String currencyCode;
  final int openingBalanceMinor;
  final int currentBalanceMinor;
  final String? maskedAccountReference;
  final String status;

  factory AccountRecord.fromMap(Map<String, Object?> row) => AccountRecord(
        id: row['id']! as String,
        institutionName: row['institution_name']! as String,
        displayName: row['display_name']! as String,
        currencyCode: row['currency_code']! as String,
        openingBalanceMinor: row['opening_balance_minor']! as int,
        currentBalanceMinor:
            (row['current_balance_minor'] as int?) ??
            (row['opening_balance_minor']! as int),
        maskedAccountReference: row['masked_account_reference'] as String?,
        status: row['status']! as String,
      );
}

class AccountRepository {
  AccountRepository({MoneyMeshDatabase? database})
      : _database = database ?? MoneyMeshDatabase.instance;

  final MoneyMeshDatabase _database;

  Future<List<AccountRecord>> getAll({bool includeArchived = false}) async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT a.*,
        a.opening_balance_minor + COALESCE(SUM(
          CASE t.direction
            WHEN 'income' THEN t.amount_minor
            WHEN 'expense' THEN -t.amount_minor
            ELSE 0
          END
        ), 0) AS current_balance_minor
      FROM financial_accounts a
      LEFT JOIN transactions t ON t.financial_account_id = a.id
      ${includeArchived ? '' : "WHERE a.status = 'active'"}
      GROUP BY a.id
      ORDER BY a.created_at ASC
    ''');
    return rows.map(AccountRecord.fromMap).toList();
  }

  Future<void> create({
    required String id,
    required String institutionName,
    required String displayName,
    required int openingBalanceMinor,
    String currencyCode = 'INR',
    String? maskedAccountReference,
  }) async {
    _validate(institutionName, displayName, openingBalanceMinor);
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('financial_accounts', {
      'id': id,
      'institution_name': institutionName.trim(),
      'display_name': displayName.trim(),
      'masked_account_reference': _cleanMask(maskedAccountReference),
      'currency_code': currencyCode,
      'opening_balance_minor': openingBalanceMinor,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> update({
    required String id,
    required String institutionName,
    required String displayName,
    required int openingBalanceMinor,
    String? maskedAccountReference,
  }) async {
    _validate(institutionName, displayName, openingBalanceMinor);
    final db = await _database.database;
    final changed = await db.update(
      'financial_accounts',
      {
        'institution_name': institutionName.trim(),
        'display_name': displayName.trim(),
        'masked_account_reference': _cleanMask(maskedAccountReference),
        'opening_balance_minor': openingBalanceMinor,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'active'],
    );
    if (changed == 0) throw StateError('Account not found or archived.');
  }

  Future<void> archive(String id) async {
    final db = await _database.database;
    await db.update(
      'financial_accounts',
      {'status': 'archived', 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static String? _cleanMask(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static void _validate(String institution, String name, int openingBalance) {
    if (institution.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Institution and account name are required.');
    }
    if (openingBalance < 0) {
      throw ArgumentError.value(openingBalance, 'openingBalanceMinor');
    }
  }
}
