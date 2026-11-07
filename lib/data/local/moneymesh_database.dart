import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens and owns MoneyMesh's on-device SQLite database.
class MoneyMeshDatabase {
  MoneyMeshDatabase._();
  static final MoneyMeshDatabase instance = MoneyMeshDatabase._();
  static const _databaseName = 'moneymesh.db';
  static const _databaseVersion = 1;
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final directory = await getDatabasesPath();
    final opened = await openDatabase(
      p.join(directory, _databaseName),
      version: _databaseVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
    );
    _database = opened;
    return opened;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE financial_accounts (
        id TEXT PRIMARY KEY,
        institution_name TEXT NOT NULL,
        display_name TEXT NOT NULL,
        masked_account_reference TEXT,
        currency_code TEXT NOT NULL DEFAULT 'INR',
        opening_balance_minor INTEGER NOT NULL DEFAULT 0 CHECK (opening_balance_minor >= 0),
        status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_apps (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_app_account_links (
        id TEXT PRIMARY KEY,
        payment_app_id TEXT NOT NULL,
        financial_account_id TEXT NOT NULL,
        label TEXT,
        created_at TEXT NOT NULL,
        UNIQUE (payment_app_id, financial_account_id),
        FOREIGN KEY (payment_app_id) REFERENCES payment_apps(id) ON DELETE CASCADE,
        FOREIGN KEY (financial_account_id) REFERENCES financial_accounts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        kind TEXT NOT NULL CHECK (kind IN ('income', 'expense', 'both')),
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE import_batches (
        id TEXT PRIMARY KEY,
        source_file_name TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        status TEXT NOT NULL,
        total_rows INTEGER NOT NULL DEFAULT 0,
        accepted_rows INTEGER NOT NULL DEFAULT 0,
        rejected_rows INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        financial_account_id TEXT NOT NULL,
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        currency_code TEXT NOT NULL DEFAULT 'INR',
        direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')),
        category_id TEXT,
        description TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'manual' CHECK (source_type IN ('manual', 'statement_import')),
        source_payment_app_id TEXT,
        external_reference TEXT,
        import_batch_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (financial_account_id) REFERENCES financial_accounts(id) ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        FOREIGN KEY (source_payment_app_id) REFERENCES payment_apps(id) ON DELETE SET NULL,
        FOREIGN KEY (import_batch_id) REFERENCES import_batches(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT,
        limit_minor INTEGER NOT NULL CHECK (limit_minor > 0),
        currency_code TEXT NOT NULL DEFAULT 'INR',
        period TEXT NOT NULL CHECK (period IN ('weekly', 'monthly')),
        start_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_transactions_account_date ON transactions(financial_account_id, occurred_at DESC)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(occurred_at DESC)');
    await db.execute('CREATE INDEX idx_payment_links_account ON payment_app_account_links(financial_account_id)');
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    await current?.close();
  }
}
