import '../local/moneymesh_database.dart';
import '../repositories/account_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';

class CsvImportResult {
  const CsvImportResult({
    required this.totalRows,
    required this.imported,
    required this.duplicates,
    required this.rejected,
    required this.errors,
  });

  final int totalRows;
  final int imported;
  final int duplicates;
  final int rejected;
  final List<String> errors;
}

/// Imports a deliberately small, documented CSV format into the local ledger.
class CsvStatementImporter {
  CsvStatementImporter({
    MoneyMeshDatabase? database,
    TransactionRepository? transactions,
    CategoryRepository? categories,
  })  : _database = database ?? MoneyMeshDatabase.instance,
        _transactions = transactions ?? TransactionRepository(),
        _categories = categories ?? CategoryRepository();

  final MoneyMeshDatabase _database;
  final TransactionRepository _transactions;
  final CategoryRepository _categories;

  Future<CsvImportResult> importText({
    required String fileName,
    required String csvText,
    required List<AccountRecord> accounts,
  }) async {
    final rows = _parseCsv(csvText);
    if (rows.length < 2) {
      throw const FormatException('The CSV file must contain a header and at least one data row.');
    }
    final headers = rows.first.map((value) => value.trim().toLowerCase()).toList();
    final dateColumn = _column(headers, ['date', 'transaction_date']);
    final descriptionColumn = _column(headers, ['description', 'details', 'narration']);
    final amountColumn = _column(headers, ['amount', 'amount_inr']);
    final directionColumn = _column(headers, ['direction', 'type']);
    final categoryColumn = _column(headers, ['category']);
    final accountColumn = _column(headers, ['account', 'account_name']);
    if ([dateColumn, descriptionColumn, amountColumn, directionColumn, accountColumn]
        .any((column) => column == -1)) {
      throw const FormatException(
        'Required CSV columns: date, description, amount, direction, account. Category is optional.',
      );
    }

    final accountByName = <String, AccountRecord>{};
    for (final account in accounts) {
      accountByName[account.displayName.trim().toLowerCase()] = account;
      accountByName[account.id.toLowerCase()] = account;
    }
    final db = await _database.database;
    final batchId = 'import-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('import_batches', {
      'id': batchId,
      'source_file_name': fileName,
      'imported_at': now,
      'status': 'processing',
      'total_rows': rows.length - 1,
      'accepted_rows': 0,
      'rejected_rows': 0,
    });

    var imported = 0;
    var duplicates = 0;
    var rejected = 0;
    final errors = <String>[];
    final categoryCache = <String, String>{};
    final knownCategories = await _categories.getAll();
    for (final category in knownCategories) {
      categoryCache[category.name.toLowerCase()] = category.id;
    }

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final rowNumber = rowIndex + 1;
      final row = rows[rowIndex];
      String value(int column) => column >= 0 && column < row.length ? row[column].trim() : '';
      try {
        final accountName = value(accountColumn).toLowerCase();
        final account = accountByName[accountName];
        if (account == null) {
          throw const FormatException('Account does not match an active MoneyMesh account.');
        }
        final description = value(descriptionColumn);
        if (description.isEmpty) throw const FormatException('Description is empty.');
        final date = _parseDate(value(dateColumn));
        final amount = _parseAmount(value(amountColumn));
        final direction = _parseDirection(value(directionColumn), amount);
        final amountMinor = amount.abs();
        if (amountMinor <= 0) throw const FormatException('Amount must be greater than zero.');

        if (await _transactions.isDuplicate(
          accountId: account.id,
          amountMinor: amountMinor,
          direction: direction,
          description: description,
          occurredAt: date,
        )) {
          duplicates++;
          continue;
        }

        final categoryName = categoryColumn == -1 || value(categoryColumn).isEmpty
            ? (direction == 'income' ? 'Other income' : 'Other expense')
            : value(categoryColumn);
        var categoryId = categoryCache[categoryName.toLowerCase()];
        if (categoryId == null) {
          categoryId = 'import-category-${DateTime.now().microsecondsSinceEpoch}-$rowIndex';
          await _categories.create(
            id: categoryId,
            name: categoryName,
            kind: direction,
          );
          categoryCache[categoryName.toLowerCase()] = categoryId;
        }
        await _transactions.save(
          id: 'import-txn-${DateTime.now().microsecondsSinceEpoch}-$rowIndex',
          accountId: account.id,
          amountMinor: amountMinor,
          currencyCode: account.currencyCode,
          direction: direction,
          description: description,
          occurredAt: date,
          categoryId: categoryId,
          importBatchId: batchId,
          sourceType: 'statement_import',
          externalReference: 'csv:$batchId:$rowNumber',
        );
        imported++;
      } on Object catch (error) {
        rejected++;
        if (errors.length < 10) errors.add('Row $rowNumber: $error');
      }
    }

    await db.update(
      'import_batches',
      {
        'status': rejected == 0 ? 'completed' : (imported == 0 ? 'failed' : 'completed_with_errors'),
        'accepted_rows': imported,
        'rejected_rows': rejected,
      },
      where: 'id = ?',
      whereArgs: [batchId],
    );

    return CsvImportResult(
      totalRows: rows.length - 1,
      imported: imported,
      duplicates: duplicates,
      rejected: rejected,
      errors: errors,
    );
  }

  static int _column(List<String> headers, List<String> names) =>
      headers.indexWhere(names.contains);

  static DateTime _parseDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return DateTime.utc(parsed.year, parsed.month, parsed.day);
    final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(value);
    if (match != null) {
      return DateTime.utc(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
    }
    throw const FormatException('Date must be YYYY-MM-DD or DD/MM/YYYY.');
  }

  /// Returns signed paise. Direction is still validated separately.
  static int _parseAmount(String value) {
    final cleaned = value.replaceAll(',', '').replaceAll('₹', '').trim();
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) throw const FormatException('Amount must have at most 2 decimal places.');
    final sign = match.group(1) == '-' ? -1 : 1;
    final rupees = int.parse(match.group(2)!);
    final paise = int.parse((match.group(3) ?? '').padRight(2, '0'));
    return sign * (rupees * 100 + paise);
  }

  static String _parseDirection(String value, int signedAmount) {
    final normalized = value.trim().toLowerCase();
    if (['income', 'credit', 'cr'].contains(normalized)) return 'income';
    if (['expense', 'debit', 'dr'].contains(normalized)) return 'expense';
    if (signedAmount < 0) return 'expense';
    throw const FormatException('Direction must be income/credit or expense/debit.');
  }

  static List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    for (var index = 0; index < input.length; index++) {
      final character = input[index];
      if (character == '"') {
        if (inQuotes && index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (character == ',' && !inQuotes) {
        row.add(field.toString().trim());
        field.clear();
      } else if ((character == '\n' || character == '\r') && !inQuotes) {
        if (character == '\r' && index + 1 < input.length && input[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString().trim());
        field.clear();
        if (row.any((cell) => cell.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(character);
      }
    }
    if (inQuotes) throw const FormatException('CSV contains an unclosed quoted field.');
    row.add(field.toString().trim());
    if (row.any((cell) => cell.isNotEmpty)) rows.add(row);
    return rows;
  }
}
