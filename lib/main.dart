import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'data/services/data_management_service.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/budget_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/payment_app_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/services/csv_statement_importer.dart';

void main() => runApp(const MoneyMeshApp());

class MoneyMeshApp extends StatelessWidget {
  const MoneyMeshApp({super.key, this.loadDataOnStart = true});

  final bool loadDataOnStart;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MoneyMesh',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7563D8),
            surface: const Color(0xFFF8F7FC),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8F7FC),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFECEAF3)),
            ),
          ),
        ),
        home: MoneyMeshHome(loadDataOnStart: loadDataOnStart),
      );
}

String formatINR(int minor) {
  final negative = minor < 0;
  final value = minor.abs();
  final rupees = value ~/ 100;
  final paise = (value % 100).toString().padLeft(2, '0');
  return '₹${negative ? '−' : ''}$rupees.$paise';
}

int? parseMinorUnits(String input) {
  final value = input.trim().replaceAll(',', '').replaceAll('₹', '');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value);
  if (match == null) return null;
  final rupees = int.tryParse(match.group(1)!);
  final paise = int.tryParse((match.group(2) ?? '').padRight(2, '0'));
  if (rupees == null || paise == null) return null;
  return rupees * 100 + paise;
}

String _newId(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

DateTime _monthStart(DateTime value) => DateTime(value.year, value.month);

String _dateLabel(String value) {
  final date = DateTime.parse(value).toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class MoneyMeshHome extends StatefulWidget {
  const MoneyMeshHome({super.key, this.loadDataOnStart = true});

  final bool loadDataOnStart;

  @override
  State<MoneyMeshHome> createState() => _MoneyMeshHomeState();
}

class _MoneyMeshHomeState extends State<MoneyMeshHome> {
  final _accountRepo = AccountRepository();
  final _transactionRepo = TransactionRepository();
  final _categoryRepo = CategoryRepository();
  final _paymentAppRepo = PaymentAppRepository();
  final _csvImporter = CsvStatementImporter();
  final _dataManagement = DataManagementService();

  int _selectedIndex = 0;
  bool _loading = true;
  String? _loadError;
  List<AccountRecord> _accounts = [];
  List<Map<String, Object?>> _transactions = [];
  List<CategoryRecord> _categories = [];
  List<Map<String, Object?>> _paymentApps = [];
  List<Map<String, Object?>> _paymentLinks = [];
  String _query = '';
  String _accountFilter = '';
  String _directionFilter = '';
  String _categoryFilter = '';
  DateTimeRange? _dateRange;
  DateTimeRange? _insightsRange;

  @override
  void initState() {
    super.initState();
    if (widget.loadDataOnStart) _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      await _categoryRepo.ensureDefaults();
      await _paymentAppRepo.ensureDefaults();
      final accounts = await _accountRepo.getAll();
      final transactions = await _transactionRepo.getAll(limit: 1000);
      final categories = await _categoryRepo.getAll();
      final apps = await _paymentAppRepo.getAppsWithAccounts();
      final links = await _paymentAppRepo.getLinks();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _transactions = transactions;
        _categories = categories;
        _paymentApps = apps;
        _paymentLinks = links;
        _loading = false;
      });

    } on Object catch (error) {
      debugPrint('MoneyMesh local database load failed: $error');
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });

    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addOrEditAccount([AccountRecord? existing]) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AccountFormDialog(account: existing),
    );
    if (result == null) return;
    try {
      final opening = parseMinorUnits(result['opening'] ?? '');
      if (opening == null) throw const FormatException('Enter a valid opening balance (maximum 2 decimal places).');
      if (existing == null) {
        await _accountRepo.create(
          id: _newId('account'),
          institutionName: result['institution']!,
          displayName: result['name']!,
          maskedAccountReference: result['mask'],
          openingBalanceMinor: opening,
        );
      } else {
        await _accountRepo.update(
          id: existing.id,
          institutionName: result['institution']!,
          displayName: result['name']!,
          maskedAccountReference: result['mask'],
          openingBalanceMinor: opening,
        );
      }
      await _loadData();
      _showMessage(existing == null ? 'Bank account added.' : 'Bank account updated.');
    } on Object catch (error) {
      _showMessage('Could not save account: $error');
    }
  }

  Future<void> _archiveAccount(AccountRecord account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive account?'),
        content: Text('“${account.displayName}” will be hidden from active totals. Its transaction history will remain saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _accountRepo.archive(account.id);
    await _loadData();
    _showMessage('Account archived. History retained.');
  }

  Future<void> _addOrEditTransaction([Map<String, Object?>? existing]) async {
    if (_accounts.isEmpty) {
      _showMessage('Add a bank account before recording transactions.');
      setState(() => _selectedIndex = 1);
      return;
    }
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _TransactionFormDialog(
        accounts: _accounts,
        categories: _categories,
        transaction: existing,
      ),
    );
    if (result == null) return;
    try {
      final amount = parseMinorUnits(result['amount']! as String);
      if (amount == null || amount <= 0) {
        throw const FormatException('Enter an amount greater than zero with at most 2 decimal places.');
      }
      final id = existing?['id'] as String?;
      final accountId = result['accountId']! as String;
      final account = _accounts.firstWhere((item) => item.id == accountId);
      final categoryId = result['categoryId'] as String?;
      final direction = result['direction']! as String;
      if (id == null) {
        await _transactionRepo.save(
          id: _newId('transaction'),
          accountId: accountId,
          amountMinor: amount,
          currencyCode: account.currencyCode,
          direction: direction,
          description: result['description']! as String,
          occurredAt: result['date']! as DateTime,
          categoryId: categoryId,
        );
      } else {
        await _transactionRepo.update(
          id: id,
          accountId: accountId,
          amountMinor: amount,
          currencyCode: account.currencyCode,
          direction: direction,
          description: result['description']! as String,
          occurredAt: result['date']! as DateTime,
          categoryId: categoryId,
        );
      }
      await _loadData();
      _showMessage(id == null ? 'Transaction saved on this device.' : 'Transaction updated.');
    } on Object catch (error) {
      _showMessage('Could not save transaction: $error');
    }
  }

  Future<void> _deleteTransaction(Map<String, Object?> transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Delete “${transaction['description']}” permanently from this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _transactionRepo.delete(transaction['id']! as String);
    await _loadData();
    _showMessage('Transaction deleted.');
  }

  Future<void> _importCsv() async {
    if (_accounts.isEmpty) {
      _showMessage('Add and select your bank accounts before importing a statement.');
      return;
    }
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('The selected CSV file is empty or could not be read.');
      }
      final text = utf8.decode(bytes, allowMalformed: false);
      final result = await _csvImporter.importText(
        fileName: file.name,
        csvText: text,
        accounts: _accounts,
      );
      await _loadData();
      _showMessage(
        'CSV complete: ${result.imported} imported, ${result.duplicates} duplicates skipped, ${result.rejected} rejected.',
      );
      if (result.errors.isNotEmpty && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Some rows need attention'),
            content: SingleChildScrollView(child: Text(result.errors.join('\n'))),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        );
      }
    } on Object catch (error) {
      _showMessage('CSV import failed: $error');
    }
  }

  Future<void> _exportData() async {
    try {
      final bytes = await _dataManagement.exportJson();
      final output = await FilePicker.saveFile(
        fileName: 'moneymesh-export-${DateTime.now().toIso8601String().split('T').first}.json',
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'Export MoneyMesh data',
      );
      if (output != null) {
        _showMessage('Your MoneyMesh data export was saved.');
      }
    } on Object catch (error) {
      _showMessage('Could not export data: $error');
    }
  }

  Future<void> _deleteAllLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: const Text(
          'This permanently removes accounts, transactions, budgets, custom categories, payment-app links and import history from this device. This cannot be undone. Export your data first if you need a copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dataManagement.deleteAllLocalData();
      await _loadData();
      _showMessage('All local finance data was deleted. Default categories and app names were restored.');
    } on Object catch (error) {
      _showMessage('Could not delete local data: $error');
    }
  }

  Future<void> _managePaymentLinks() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _PaymentLinkFormDialog(
        apps: _paymentApps,
        accounts: _accounts,
      ),
    );
    if (result == null) return;
    try {
      await _paymentAppRepo.link(
        id: _newId('payment-link'),
        paymentAppId: result.$1,
        accountId: result.$2,
      );
      await _loadData();
      _showMessage('Payment app linked to the existing bank account. Balance not duplicated.');
    } on Object catch (error) {
      _showMessage('Could not link app: $error');
    }
  }

  Future<void> _unlinkPayment(String linkId) async {
    await _paymentAppRepo.unlink(linkId);
    await _loadData();
  }

  Future<void> _openBudgets() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BudgetScreen(categories: _categories),
      ),
    );
    await _loadData();
  }

  Future<void> _openCategories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CategoryScreen()),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _loading
          ? const Center(child: Text('Loading your local finance data…'))
          : _loadError != null
              ? _ErrorPanel(message: _loadError!, onRetry: _loadData)
              : _dashboardPage(),
      _accountsPage(),
      _activityPage(),
      _insightsPage(),
      _settingsPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7FC),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF7563D8)),
            SizedBox(width: 9),
            Text('MoneyMesh', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh data',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) => setState(() => _selectedIndex = value),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFECE8FF),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.account_balance_rounded), label: 'Accounts'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _dashboardPage() {
    final total = _accounts.fold<int>(0, (sum, account) => sum + account.currentBalanceMinor);
    final latest = _transactions.take(4).toList();
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          const Text('YOUR FINANCES, CONNECTED', style: TextStyle(
            color: Color(0xFF817B91), fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 8),
          const Text('Your money at a glance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          _TotalBalanceCard(totalMinor: total, accountCount: _accounts.length),
          const SizedBox(height: 24),
          _SectionHeading(title: 'Bank accounts', trailing: TextButton.icon(
            onPressed: () => setState(() => _selectedIndex = 1),
            icon: const Icon(Icons.manage_accounts_outlined, size: 17),
            label: const Text('Manage'),
          )),
          if (_accounts.isEmpty)
            const _EmptyPanel(
              icon: Icons.account_balance_outlined,
              title: 'Add your first bank account',
              message: 'Enter an account name and opening balance. MoneyMesh stores the data locally.',
            )
          else
            ..._accounts.take(3).map((account) => _AccountTile(
              account: account,
              onTap: () => setState(() => _selectedIndex = 1),
            )),
          const SizedBox(height: 20),
          _SectionHeading(title: 'Linked payment apps', trailing: TextButton(
            onPressed: _managePaymentLinks,
            child: const Text('Manage links'),
          )),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < _paymentApps.length; index++) ...[
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF0EEFA),
                      child: Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF7563D8)),
                    ),
                    title: Text(_paymentApps[index]['name']! as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${_paymentApps[index]['linked_accounts']} linked bank accounts'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _managePaymentLinks,
                  ),
                  if (index != _paymentApps.length - 1) const Divider(height: 1, indent: 70),
                ],
                if (_paymentApps.isEmpty) const ListTile(title: Text('No payment apps yet')),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SectionHeading(title: 'Recent transactions', trailing: TextButton(
            onPressed: () => setState(() => _selectedIndex = 2),
            child: const Text('View all'),
          )),
          if (latest.isEmpty)
            const _EmptyPanel(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              message: 'Add an income or expense to start your financial record.',
            )
          else
            ...latest.map(_transactionTile),
          const SizedBox(height: 12),
          const _PrivacyNotice(),
        ],
      ),
    );
  }

  Widget _accountsPage() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                const Expanded(child: Text('Bank accounts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                FilledButton.icon(
                  onPressed: () => _addOrEditAccount(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add account'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _accounts.isEmpty
                ? const _EmptyPanel(
                    icon: Icons.account_balance_outlined,
                    title: 'No bank accounts',
                    message: 'Add an account to track its opening balance and transactions.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: _accounts.map((account) => Card(
                      child: Column(
                        children: [
                          _AccountTile(account: account),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _addOrEditAccount(account),
                                  icon: const Icon(Icons.edit_outlined, size: 17),
                                  label: const Text('Edit'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _archiveAccount(account),
                                  icon: const Icon(Icons.archive_outlined, size: 17),
                                  label: const Text('Archive'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
          ),
        ],
      );

  Future<void> _selectDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      helpText: 'Filter transactions by date',
    );
    if (selected != null) {
      setState(() => _dateRange = selected);
    }
  }

  Widget _activityPage() {
    final visible = _transactions.where((transaction) {
      final description = (transaction['description']! as String).toLowerCase();
      final category = (transaction['category_name'] as String? ?? '').toLowerCase();
      final queryMatches = _query.isEmpty || description.contains(_query.toLowerCase()) || category.contains(_query.toLowerCase());
      final accountMatches = _accountFilter.isEmpty || transaction['financial_account_id'] == _accountFilter;
      final directionMatches = _directionFilter.isEmpty || transaction['direction'] == _directionFilter;
      final categoryMatches = _categoryFilter.isEmpty || transaction['category_id'] == _categoryFilter;
      final date = DateTime.parse(transaction['occurred_at']! as String).toLocal();
      final rangeMatches = _dateRange == null ||
          (!date.isBefore(DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day)) &&
           !date.isAfter(DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59, 999)));
      return queryMatches && accountMatches && directionMatches && categoryMatches && rangeMatches;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            children: [
              const Expanded(child: Text('Activity', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: 'Import CSV statement',
                onPressed: _importCsv,
                icon: const Icon(Icons.file_upload_outlined),
              ),
              FilledButton.icon(
                onPressed: () => _addOrEditTransaction(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search description or category',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _directionFilter,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All types')),
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  ],
                  onChanged: (value) => setState(() => _directionFilter = value ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _accountFilter,
                  decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All accounts')),
                    ..._accounts.map((account) => DropdownMenuItem(value: account.id, child: Text(account.displayName, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) => setState(() => _accountFilter = value ?? ''),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _categoryFilter,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All categories')),
                    ..._categories.map((item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (value) => setState(() => _categoryFilter = value ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(_dateRange == null
                    ? 'Date range'
                    : '${_dateRange!.start.day}/${_dateRange!.start.month}–${_dateRange!.end.day}/${_dateRange!.end.month}'),
              ),
              if (_dateRange != null)
                IconButton(
                  tooltip: 'Clear date range',
                  onPressed: () => setState(() => _dateRange = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const _EmptyPanel(
                  icon: Icons.search_off_rounded,
                  title: 'No matching transactions',
                  message: 'Add a transaction or change your search and filters.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => _transactionTile(visible[index]),
                ),
        ),
      ],
    );
  }

  Widget _insightsPage() {
    final now = DateTime.now();
    final range = _insightsRange ??
        DateTimeRange(start: _monthStart(now), end: now);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );
    final monthRows = _transactions.where((row) {
      final date = DateTime.parse(row['occurred_at']! as String).toLocal();
      return !date.isBefore(start) && !date.isAfter(end);
    });
    var income = 0;
    var expenses = 0;
    final categorySpend = <String, int>{};
    for (final row in monthRows) {
      final amount = row['amount_minor']! as int;
      if (row['direction'] == 'income') {
        income += amount;
      } else {
        expenses += amount;
        final category = row['category_name'] as String? ?? 'Uncategorised';
        categorySpend[category] = (categorySpend[category] ?? 0) + amount;
      }
    }
    final sorted = categorySpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Insights', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_dateLabel(range.start.toIso8601String())} – ${_dateLabel(range.end.toIso8601String())}',
                style: const TextStyle(color: Color(0xFF817B91)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  initialDateRange: range,
                  helpText: 'Select report date range',
                );
                if (selected != null) {
                  setState(() => _insightsRange = selected);
                }
              },
              icon: const Icon(Icons.date_range_outlined, size: 17),
              label: const Text('Range'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InsightCard(title: 'Recorded income', amount: income, icon: Icons.trending_up_rounded, tint: const Color(0xFF16845B)),
        const SizedBox(height: 10),
        _InsightCard(title: 'Recorded expenses', amount: expenses, icon: Icons.trending_down_rounded, tint: const Color(0xFFB34D61)),
        const SizedBox(height: 10),
        _InsightCard(title: 'Net activity', amount: income - expenses, icon: Icons.account_balance_wallet_outlined, tint: const Color(0xFF7563D8)),
        const SizedBox(height: 22),
        const Text('Spending by category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const _EmptyPanel(icon: Icons.pie_chart_outline_rounded, title: 'No spending yet', message: 'Expense categories appear here after you record transactions.')
        else
          ...sorted.map((entry) {
            final fraction = expenses == 0 ? 0.0 : entry.value / expenses;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(formatINR(entry.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(value: fraction, minHeight: 8, backgroundColor: const Color(0xFFECEAF3)),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 12),
        const _PrivacyNotice(),
      ],
    );
  }

  Widget _settingsPage() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Manage your MoneyMesh preferences.', style: TextStyle(color: Color(0xFF817B91))),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Budgets'),
                  subtitle: const Text('Set weekly or monthly spending limits'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openBudgets,
                ),
                const Divider(height: 1, indent: 58),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Categories'),
                  subtitle: const Text('Manage income and expense categories'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openCategories,
                ),
                const Divider(height: 1, indent: 58),
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('Payment app links'),
                  subtitle: const Text('Link apps to existing bank accounts'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _managePaymentLinks,
                ),
                const Divider(height: 1, indent: 58),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Export local data'),
                  subtitle: const Text('Save a JSON copy of your finance records'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _exportData,
                ),
                const Divider(height: 1, indent: 58),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB34D61)),
                  title: const Text('Delete all local data'),
                  subtitle: const Text('Permanently erase MoneyMesh records on this device'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _deleteAllLocalData,
                ),
                const Divider(height: 1, indent: 58),
                const ListTile(
                  leading: Icon(Icons.lock_outline_rounded),
                  title: Text('Privacy & security'),
                  subtitle: Text('Finance data is stored locally. No bank passwords, OTPs or UPI PINs are requested.'),
                ),
                const Divider(height: 1, indent: 58),
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('About MoneyMesh'),
                  subtitle: Text('All Your Money in One Place. Tracking only; no payments or transfers.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_paymentLinks.isNotEmpty) ...[
            const Text('Linked accounts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: _paymentLinks.map((link) => ListTile(
                  title: Text(link['app_name']! as String),
                  subtitle: Text(link['account_name']! as String),
                  trailing: IconButton(
                    tooltip: 'Unlink account',
                    onPressed: () => _unlinkPayment(link['id']! as String),
                    icon: const Icon(Icons.link_off_rounded),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const _PrivacyNotice(),
        ],
      );

  Widget _transactionTile(Map<String, Object?> transaction) {
    final income = transaction['direction'] == 'income';
    final amount = transaction['amount_minor']! as int;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: CircleAvatar(
          backgroundColor: income ? const Color(0xFFE6F4ED) : const Color(0xFFFCEDEF),
          child: Icon(income ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: income ? const Color(0xFF16845B) : const Color(0xFFB34D61)),
        ),
        title: Text(transaction['description']! as String, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${transaction['category_name'] ?? 'Uncategorised'} · ${transaction['account_name'] ?? 'Account'}\n${_dateLabel(transaction['occurred_at']! as String)} · ${transaction['source_type'] == 'statement_import' ? 'Imported' : 'Manual'}',
          style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF817B91)),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _addOrEditTransaction(transaction);
            if (value == 'delete') _deleteTransaction(transaction);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${income ? '+' : '−'}${formatINR(amount)}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: income ? const Color(0xFF16845B) : const Color(0xFF363243))),
              const Icon(Icons.more_horiz_rounded, color: Color(0xFF817B91)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountFormDialog extends StatefulWidget {
  const _AccountFormDialog({this.account});
  final AccountRecord? account;

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  late final TextEditingController _institution;
  late final TextEditingController _name;
  late final TextEditingController _mask;
  late final TextEditingController _opening;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _institution = TextEditingController(text: account?.institutionName ?? '');
    _name = TextEditingController(text: account?.displayName ?? '');
    _mask = TextEditingController(text: account?.maskedAccountReference ?? '');
    _opening = TextEditingController(
      text: account == null ? '' : '${account.openingBalanceMinor ~/ 100}.${(account.openingBalanceMinor % 100).toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _institution.dispose();
    _name.dispose();
    _mask.dispose();
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.account == null ? 'Add bank account' : 'Edit bank account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _institution, decoration: const InputDecoration(labelText: 'Bank / institution')),
              const SizedBox(height: 10),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Account display name')),
              const SizedBox(height: 10),
              TextField(controller: _mask, decoration: const InputDecoration(labelText: 'Masked reference (optional)', hintText: '•••• 1234')),
              const SizedBox(height: 10),
              TextField(controller: _opening, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Opening balance (₹)')),
              const SizedBox(height: 8),
              const Text('Do not enter a full account number, PIN, password or OTP.', style: TextStyle(fontSize: 11, color: Color(0xFF817B91))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (_institution.text.trim().isEmpty || _name.text.trim().isEmpty || parseMinorUnits(_opening.text) == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the bank, account name and a valid opening balance.')));
                return;
              }
              Navigator.pop(context, {
                'institution': _institution.text.trim(),
                'name': _name.text.trim(),
                'mask': _mask.text.trim(),
                'opening': _opening.text.trim(),
              });
            },
            child: const Text('Save account'),
          ),
        ],
      );
}

class _TransactionFormDialog extends StatefulWidget {
  const _TransactionFormDialog({
    required this.accounts,
    required this.categories,
    this.transaction,
  });

  final List<AccountRecord> accounts;
  final List<CategoryRecord> categories;
  final Map<String, Object?>? transaction;

  @override
  State<_TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<_TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late String _direction;
  late String _accountId;
  String? _categoryId;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _description = TextEditingController(text: transaction?['description'] as String? ?? '');
    final amount = transaction?['amount_minor'] as int?;
    _amount = TextEditingController(text: amount == null ? '' : '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}');
    _direction = transaction?['direction'] as String? ?? 'expense';
    _accountId = transaction?['financial_account_id'] as String? ?? widget.accounts.first.id;
    _categoryId = transaction?['category_id'] as String?;
    _date = transaction == null ? DateTime.now() : DateTime.parse(transaction['occurred_at']! as String).toLocal();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories.where((item) => item.kind == _direction || item.kind == 'both').toList();
    final selectedCategory = categories.any((item) => item.id == _categoryId) ? _categoryId : null;
    return AlertDialog(
      title: Text(widget.transaction == null ? 'Add transaction' : 'Edit transaction'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {_direction},
                onSelectionChanged: (selection) => setState(() {
                  _direction = selection.first;
                  if (!categories.any((item) => item.id == _categoryId)) _categoryId = null;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter a description' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                validator: (value) {
                  final amount = parseMinorUnits(value ?? '');
                  return amount == null || amount <= 0 ? 'Enter a valid positive amount' : null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: 'Bank account', border: OutlineInputBorder()),
                items: widget.accounts.map((account) => DropdownMenuItem(value: account.id, child: Text(account.displayName))).toList(),
                onChanged: (value) => setState(() => _accountId = value ?? _accountId),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: categories.map((category) => DropdownMenuItem(value: category.id, child: Text(category.name))).toList(),
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? 'Select a category' : null,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (selected != null) setState(() => _date = selected);
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Date: ${_date.day}/${_date.month}/${_date.year}'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, <String, Object?>{
              'description': _description.text.trim(),
              'amount': _amount.text.trim(),
              'direction': _direction,
              'accountId': _accountId,
              'categoryId': _categoryId,
              'date': _date,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({required this.categories, super.key});
  final List<CategoryRecord> categories;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _repository = BudgetRepository();
  bool _loading = true;
  List<Map<String, Object?>> _budgets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final budgets = await _repository.getActiveWithProgress();
    if (mounted) {
      setState(() {
        _budgets = budgets;
        _loading = false;
      });
    }
  }

  Future<void> _addBudget() async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _BudgetFormDialog(categories: widget.categories),
    );
    if (result == null) return;
    try {
      final amount = parseMinorUnits(result['amount']! as String);
      if (amount == null || amount <= 0) throw const FormatException('Enter a valid budget amount.');
      await _repository.create(
        id: _newId('budget'),
        limitMinor: amount,
        period: result['period']! as String,
        startDate: DateTime.now(),
        categoryId: result['categoryId'] as String?,
      );
      await _load();
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create budget: $error')));
    }
  }

  Future<void> _archive(String id) async {
    await _repository.archive(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Budgets')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addBudget,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New budget'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _budgets.isEmpty
                ? const _EmptyPanel(icon: Icons.savings_outlined, title: 'No budgets yet', message: 'Create a weekly or monthly limit to track your spending.')
                : ListView(
                    padding: const EdgeInsets.all(18),
                    children: _budgets.map((budget) {
                      final limit = budget['limit_minor']! as int;
                      final spent = budget['spent_minor']! as int;
                      final progress = limit == 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
                      final category = budget['category_name'] as String? ?? 'All categories';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text(category, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                                IconButton(onPressed: () => _archive(budget['id']! as String), tooltip: 'Archive budget', icon: const Icon(Icons.archive_outlined)),
                              ]),
                              Text('${budget['period']} budget · ${formatINR(spent)} of ${formatINR(limit)}'),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: const Color(0xFFECEAF3)),
                              ),
                              const SizedBox(height: 6),
                              Text(spent > limit ? 'Over budget by ${formatINR(spent - limit)}' : '${formatINR(limit - spent)} remaining',
                                style: TextStyle(fontWeight: FontWeight.w700, color: spent > limit ? const Color(0xFFB34D61) : const Color(0xFF16845B))),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
      );
}

class _BudgetFormDialog extends StatefulWidget {
  const _BudgetFormDialog({required this.categories});
  final List<CategoryRecord> categories;

  @override
  State<_BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends State<_BudgetFormDialog> {
  final _amount = TextEditingController();
  String _period = 'monthly';
  String _categoryId = '';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = widget.categories.where((item) => item.kind == 'expense' || item.kind == 'both').toList();
    return AlertDialog(
      title: const Text('Create budget'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Limit (₹)')),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ],
            selected: {_period},
            onSelectionChanged: (value) => setState(() => _period = value.first),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All expense categories')),
              ...expenseCategories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))),
            ],
            onChanged: (value) => setState(() => _categoryId = value ?? ''),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (parseMinorUnits(_amount.text) == null || parseMinorUnits(_amount.text)! <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid positive limit.')));
              return;
            }
            Navigator.pop(context, {
              'amount': _amount.text,
              'period': _period,
              'categoryId': _categoryId.isEmpty ? null : _categoryId,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _repository = CategoryRepository();
  List<CategoryRecord> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _repository.ensureDefaults();
    final values = await _repository.getAll();
    if (mounted) {
      setState(() {
        _categories = values;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _CategoryFormDialog(),
    );
    if (result == null) return;
    try {
      await _repository.create(id: _newId('category'), name: result.$1, kind: result.$2);
      await _load();
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add category: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Categories')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add category'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: _categories.map((item) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(item.kind == 'income' ? Icons.south_west_rounded : Icons.category_outlined)),
                    title: Text(item.name),
                    trailing: Text(item.kind, style: const TextStyle(color: Color(0xFF817B91))),
                  ),
                )).toList(),
              ),
      );
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog();

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _name = TextEditingController();
  String _kind = 'expense';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Category name')),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_kind},
              onSelectionChanged: (value) => setState(() => _kind = value.first),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (_name.text.trim().isEmpty) return;
              Navigator.pop(context, (_name.text.trim(), _kind));
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class _PaymentLinkFormDialog extends StatefulWidget {
  const _PaymentLinkFormDialog({required this.apps, required this.accounts});
  final List<Map<String, Object?>> apps;
  final List<AccountRecord> accounts;

  @override
  State<_PaymentLinkFormDialog> createState() => _PaymentLinkFormDialogState();
}

class _PaymentLinkFormDialogState extends State<_PaymentLinkFormDialog> {
  String? _appId;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _appId = widget.apps.isEmpty ? null : widget.apps.first['id']! as String;
    _accountId = widget.accounts.isEmpty ? null : widget.accounts.first.id;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Link payment app'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _appId,
              decoration: const InputDecoration(labelText: 'Payment app'),
              items: widget.apps.map((app) => DropdownMenuItem(value: app['id']! as String, child: Text(app['name']! as String))).toList(),
              onChanged: (value) => setState(() => _appId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Existing bank account'),
              items: widget.accounts.map((account) => DropdownMenuItem(value: account.id, child: Text(account.displayName))).toList(),
              onChanged: (value) => setState(() => _accountId = value),
            ),
            const SizedBox(height: 8),
            const Text('This only links records. It never adds another bank balance.', style: TextStyle(fontSize: 11, color: Color(0xFF817B91))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: _appId == null || _accountId == null ? null : () => Navigator.pop(context, (_appId!, _accountId!)),
            child: const Text('Link account'),
          ),
        ],
      );
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.totalMinor, required this.accountCount});
  final int totalMinor;
  final int accountCount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7563D8), Color(0xFF5946B8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Combined balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text(formatINR(totalMinor), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.shield_outlined, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Text('$accountCount active unique bank accounts', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ],
        ),
      );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, this.onTap});
  final AccountRecord account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFF0EEFA),
            child: Icon(Icons.account_balance_rounded, color: Color(0xFF7563D8)),
          ),
          title: Text(account.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${account.institutionName}${account.maskedAccountReference == null ? '' : ' · ${account.maskedAccountReference}'}'),
          trailing: Text(formatINR(account.currentBalanceMinor), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ],
      );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.title, required this.amount, required this.icon, required this.tint});
  final String title;
  final int amount;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: CircleAvatar(backgroundColor: tint.withValues(alpha: 0.10), child: Icon(icon, color: tint)),
          title: Text(title),
          trailing: Text(formatINR(amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
        child: Column(
          children: [
            Icon(icon, size: 34, color: const Color(0xFF9B95AD)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF817B91), fontSize: 12, height: 1.5)),
          ],
        ),
      );
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF2E4C6)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF9B6A18), size: 18),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'MoneyMesh stores records on this device. No live bank or payment-app connection is active. Payment apps are linked channels, not balances.',
                style: TextStyle(color: Color(0xFF795820), fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 38, color: Color(0xFFB34D61)),
              const SizedBox(height: 12),
              const Text('Could not load MoneyMesh data', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}
