import 'package:sqflite/sqflite.dart';

import '../local/moneymesh_database.dart';

class CategoryRecord {
  const CategoryRecord({
    required this.id,
    required this.name,
    required this.kind,
  });

  final String id;
  final String name;
  final String kind;

  factory CategoryRecord.fromMap(Map<String, Object?> row) => CategoryRecord(
        id: row['id']! as String,
        name: row['name']! as String,
        kind: row['kind']! as String,
      );
}

class CategoryRepository {
  CategoryRepository({MoneyMeshDatabase? database})
      : _database = database ?? MoneyMeshDatabase.instance;

  final MoneyMeshDatabase _database;

  static const defaults = <(String, String)>[
    ('Food & groceries', 'expense'),
    ('Transport', 'expense'),
    ('Shopping', 'expense'),
    ('Bills & utilities', 'expense'),
    ('Education', 'expense'),
    ('Health', 'expense'),
    ('Entertainment', 'expense'),
    ('Other expense', 'expense'),
    ('Salary & stipend', 'income'),
    ('Business', 'income'),
    ('Other income', 'income'),
  ];

  Future<void> ensureDefaults() async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (var index = 0; index < defaults.length; index++) {
        final item = defaults[index];
        await txn.insert(
          'categories',
          {
            'id': 'default-category-$index',
            'name': item.$1,
            'kind': item.$2,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<CategoryRecord>> getAll({String? kind}) async {
    final db = await _database.database;
    final rows = await db.query(
      'categories',
      where: kind == null || kind == 'both' ? null : '(kind = ? OR kind = ?)',
      whereArgs: kind == null || kind == 'both' ? null : [kind, 'both'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(CategoryRecord.fromMap).toList();
  }

  Future<void> create({
    required String id,
    required String name,
    required String kind,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Category name is required.');
    if (!['income', 'expense', 'both'].contains(kind)) {
      throw ArgumentError.value(kind, 'kind');
    }
    final db = await _database.database;
    await db.insert('categories', {
      'id': id,
      'name': name.trim(),
      'kind': kind,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }
}
