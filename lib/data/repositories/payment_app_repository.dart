import 'package:sqflite/sqflite.dart';

import '../local/moneymesh_database.dart';

class PaymentAppRepository {
  PaymentAppRepository({MoneyMeshDatabase? database})
      : _database = database ?? MoneyMeshDatabase.instance;

  final MoneyMeshDatabase _database;

  static const defaults = ['Google Pay', 'PhonePe', 'Paytm', 'BHIM'];

  Future<void> ensureDefaults() async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final name in defaults) {
        await txn.insert(
          'payment_apps',
          {
            'id': 'payment-app-${name.toLowerCase().replaceAll(' ', '-')}',
            'name': name,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<Map<String, Object?>>> getAppsWithAccounts() async {
    final db = await _database.database;
    return db.rawQuery('''
      SELECT p.id, p.name, COUNT(a.id) AS linked_accounts
      FROM payment_apps p
      LEFT JOIN payment_app_account_links l ON l.payment_app_id = p.id
      LEFT JOIN financial_accounts a
        ON a.id = l.financial_account_id AND a.status = 'active'
      GROUP BY p.id
      ORDER BY p.name COLLATE NOCASE
    ''');
  }

  Future<List<Map<String, Object?>>> getLinks() async {
    final db = await _database.database;
    return db.rawQuery('''
      SELECT l.id, l.payment_app_id, l.financial_account_id,
        p.name AS app_name, a.display_name AS account_name
      FROM payment_app_account_links l
      JOIN payment_apps p ON p.id = l.payment_app_id
      JOIN financial_accounts a ON a.id = l.financial_account_id
      WHERE a.status = 'active'
      ORDER BY p.name, a.display_name
    ''');
  }

  Future<void> link({
    required String id,
    required String paymentAppId,
    required String accountId,
  }) async {
    final db = await _database.database;
    await db.insert('payment_app_account_links', {
      'id': id,
      'payment_app_id': paymentAppId,
      'financial_account_id': accountId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> unlink(String id) async {
    final db = await _database.database;
    await db.delete(
      'payment_app_account_links',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
