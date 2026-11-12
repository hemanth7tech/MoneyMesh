import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:moneymesh/data/local/moneymesh_database.dart';
import 'package:moneymesh/data/repositories/account_repository.dart';
import 'package:moneymesh/data/repositories/budget_repository.dart';
import 'package:moneymesh/data/repositories/category_repository.dart';
import 'package:moneymesh/data/repositories/payment_app_repository.dart';
import 'package:moneymesh/data/repositories/transaction_repository.dart';
import 'package:moneymesh/data/services/csv_statement_importer.dart';
import 'package:moneymesh/data/services/data_management_service.dart';

void main() {
  late AccountRepository accounts;
  late TransactionRepository transactions;
  late CategoryRepository categories;
  late PaymentAppRepository paymentApps;
  late BudgetRepository budgets;
  late DataManagementService dataManagement;
  late MoneyMeshDatabase database;

  setUpAll(() async {
    ffi.sqfliteFfiInit();
    sqflite.databaseFactory = ffi.databaseFactoryFfi;
    final path = '${await sqflite.getDatabasesPath()}/moneymesh.db';
    await sqflite.deleteDatabase(path);
  });

  setUp(() async {
    database = MoneyMeshDatabase.instance;
    accounts = AccountRepository(database: database);
    transactions = TransactionRepository(database: database);
    categories = CategoryRepository(database: database);
    paymentApps = PaymentAppRepository(database: database);
    budgets = BudgetRepository(database: database);
    dataManagement = DataManagementService(database: database);
    await categories.ensureDefaults();
    await paymentApps.ensureDefaults();
  });

  tearDownAll(() async {
    await database.close();
  });

  test('account balance is derived from integer-paise ledger entries', () async {
    await accounts.create(
      id: 'test-account-main',
      institutionName: 'Example Bank',
      displayName: 'Main account',
      openingBalanceMinor: 100000,
    );
    final transport = (await categories.getAll())
        .firstWhere((item) => item.name == 'Transport');

    await transactions.save(
      id: 'test-expense-1',
      accountId: 'test-account-main',
      amountMinor: 4500,
      currencyCode: 'INR',
      direction: 'expense',
      description: 'Bus ticket',
      occurredAt: DateTime.now(),
      categoryId: transport.id,
    );

    var records = await accounts.getAll();
    expect(records.single.openingBalanceMinor, 100000);
    expect(records.single.currentBalanceMinor, 95500);

    await transactions.update(
      id: 'test-expense-1',
      accountId: 'test-account-main',
      amountMinor: 3000,
      currencyCode: 'INR',
      direction: 'expense',
      description: 'Bus ticket revised',
      occurredAt: DateTime.now(),
      categoryId: transport.id,
    );
    records = await accounts.getAll();
    expect(records.single.currentBalanceMinor, 97000);

    await transactions.delete('test-expense-1');
    records = await accounts.getAll();
    expect(records.single.currentBalanceMinor, 100000);
  });

  test('payment app links never create an additional account balance', () async {
    await accounts.create(
      id: 'test-account-linked',
      institutionName: 'Example Bank',
      displayName: 'Linked account',
      openingBalanceMinor: 75000,
    );
    final apps = await paymentApps.getAppsWithAccounts();
    final googlePay = apps.firstWhere((app) => app['name'] == 'Google Pay');

    await paymentApps.link(
      id: 'test-link-gpay',
      paymentAppId: googlePay['id']! as String,
      accountId: 'test-account-linked',
    );

    final before = (await accounts.getAll()).single.currentBalanceMinor;
    final after = (await accounts.getAll()).single.currentBalanceMinor;
    final updatedApps = await paymentApps.getAppsWithAccounts();
    final updatedGooglePay =
        updatedApps.firstWhere((app) => app['name'] == 'Google Pay');

    expect(before, 75000);
    expect(after, before);
    expect(updatedGooglePay['linked_accounts'], 1);
  });

  test('CSV imports valid rows and skips an exact duplicate', () async {
    await accounts.create(
      id: 'test-account-csv',
      institutionName: 'Example Bank',
      displayName: 'CSV account',
      openingBalanceMinor: 100000,
    );
    final importer = CsvStatementImporter(
      database: database,
      transactions: transactions,
      categories: categories,
    );
    const csv = 'date,description,amount,direction,account,category\n'
        '2026-11-10,Bus ticket,45.00,expense,CSV account,Transport\n';

    final first = await importer.importText(
      fileName: 'statement.csv',
      csvText: csv,
      accounts: await accounts.getAll(),
    );
    final second = await importer.importText(
      fileName: 'statement-again.csv',
      csvText: csv,
      accounts: await accounts.getAll(),
    );

    expect(first.imported, 1);
    expect(first.duplicates, 0);
    expect(second.imported, 0);
    expect(second.duplicates, 1);
  });

  test('monthly budget progress is calculated for its current period', () async {
    await accounts.create(
      id: 'test-account-budget',
      institutionName: 'Example Bank',
      displayName: 'Budget account',
      openingBalanceMinor: 100000,
    );
    final food = (await categories.getAll())
        .firstWhere((item) => item.name == 'Food & groceries');
    await transactions.save(
      id: 'test-food-expense',
      accountId: 'test-account-budget',
      amountMinor: 2500,
      currencyCode: 'INR',
      direction: 'expense',
      description: 'Lunch',
      occurredAt: DateTime.now(),
      categoryId: food.id,
    );
    await budgets.create(
      id: 'test-monthly-budget',
      limitMinor: 10000,
      period: 'monthly',
      startDate: DateTime.now(),
      categoryId: food.id,
    );

    final rows = await budgets.getActiveWithProgress();
    final budget = rows.singleWhere((item) => item['id'] == 'test-monthly-budget');
    expect(budget['spent_minor'], 2500);
  });

  test('JSON export includes finance records and delete removes local data', () async {
    await accounts.create(
      id: 'test-account-export',
      institutionName: 'Example Bank',
      displayName: 'Export account',
      openingBalanceMinor: 50000,
    );
    final bytes = await dataManagement.exportJson();
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    expect(decoded['format'], 'moneymesh-local-export');
    expect((data['financial_accounts'] as List).length, 1);
    expect((data['payment_apps'] as List).length, greaterThan(0));

    await dataManagement.deleteAllLocalData();
    final db = await database.database;
    expect(await db.query('financial_accounts'), isEmpty);
    expect(await db.query('transactions'), isEmpty);
    expect(await db.query('budgets'), isEmpty);
    expect(await db.query('categories'), isEmpty);
    expect(await db.query('payment_apps'), isEmpty);
    expect(await db.query('payment_app_account_links'), isEmpty);
    expect(await db.query('import_batches'), isEmpty);
  });
}
