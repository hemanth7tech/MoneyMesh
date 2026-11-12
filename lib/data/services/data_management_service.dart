import 'dart:convert';
import 'dart:typed_data';

import '../local/moneymesh_database.dart';

/// Exports or deletes only the finance records stored by this local app.
class DataManagementService {
  DataManagementService({MoneyMeshDatabase? database})
      : _database = database ?? MoneyMeshDatabase.instance;

  final MoneyMeshDatabase _database;

  Future<Uint8List> exportJson() async {
    final db = await _database.database;
    final export = <String, Object?>{
      'format': 'moneymesh-local-export',
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'currency': 'INR',
      'data': {
        'financial_accounts': await db.query('financial_accounts', orderBy: 'created_at'),
        'transactions': await db.query('transactions', orderBy: 'occurred_at'),
        'categories': await db.query('categories', orderBy: 'name'),
        'budgets': await db.query('budgets', orderBy: 'created_at'),
        'payment_apps': await db.query('payment_apps', orderBy: 'name'),
        'payment_app_account_links': await db.query('payment_app_account_links'),
        'import_batches': await db.query('import_batches', orderBy: 'imported_at'),
      },
    };
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(export)));
  }

  Future<void> deleteAllLocalData() async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('budgets');
      await txn.delete('transactions');
      await txn.delete('payment_app_account_links');
      await txn.delete('import_batches');
      await txn.delete('financial_accounts');
      await txn.delete('categories');
      await txn.delete('payment_apps');
    });
  }
}
