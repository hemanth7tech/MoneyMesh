import 'package:flutter/material.dart';

void main() => runApp(const MoneyMeshApp());

class MoneyMeshApp extends StatelessWidget {
  const MoneyMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFECEAF3)),
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class BankAccount {
  const BankAccount(this.name, this.mask, this.balance, this.color);
  final String name;
  final String mask;
  final double balance;
  final Color color;
}

class MoneyTransaction {
  const MoneyTransaction({
    required this.title,
    required this.category,
    required this.when,
    required this.amount,
    required this.source,
    required this.account,
    this.income = false,
  });

  final String title;
  final String category;
  final String when;
  final double amount;
  final String source;
  final String account;
  final bool income;
}

const accounts = [
  BankAccount('State Bank of India', 'SBI •••• 2481', 32750, Color(0xFF3767B1)),
  BankAccount('Union Bank', 'Union Bank •••• 7310', 25500, Color(0xFFB34D61)),
];

const transactions = [
  MoneyTransaction(
    title: 'Grocery Store',
    category: 'Shopping',
    when: 'Today • 10:42 AM',
    amount: 1250,
    source: 'Google Pay',
    account: 'SBI •••• 2481',
  ),
  MoneyTransaction(
    title: 'Monthly stipend',
    category: 'Income',
    when: 'Yesterday • 9:15 AM',
    amount: 5000,
    source: 'Bank transfer',
    account: 'Union Bank •••• 7310',
    income: true,
  ),
  MoneyTransaction(
    title: 'Fuel Station',
    category: 'Transport',
    when: 'Nov 3 • 6:20 PM',
    amount: 800,
    source: 'PhonePe',
    account: 'SBI •••• 2481',
  ),
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final List<MoneyTransaction> _recordedTransactions =
      List<MoneyTransaction>.of(transactions);

  void _addTransaction(MoneyTransaction transaction) {
    setState(() => _recordedTransactions.insert(0, transaction));
  }

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold<double>(0, (sum, account) => sum + account.balance);
    final pages = [
      _DashboardContent(total: total, transactions: _recordedTransactions),
      _TransactionsScreen(
        transactions: _recordedTransactions,
        onAdd: _addTransaction,
      ),
      _InsightsScreen(transactions: _recordedTransactions),
      const _SettingsScreen(),
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
            tooltip: 'Notifications',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You are all caught up.')),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _BottomNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.total, required this.transactions});
  final double total;
  final List<MoneyTransaction> transactions;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            'YOUR FINANCES, CONNECTED',
            style: TextStyle(
              color: Color(0xFF817B91),
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Good day 👋',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          _TotalCard(total: total),
          const SizedBox(height: 26),
          const _SectionHeading(title: 'Bank accounts', trailing: '2 accounts'),
          const SizedBox(height: 12),
          ...accounts.map((account) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AccountCard(account: account),
              )),
          const SizedBox(height: 16),
          const _SectionHeading(
              title: 'Linked payment apps', trailing: 'Tracking only'),
          const SizedBox(height: 12),
          const _PaymentAppsCard(),
          const SizedBox(height: 24),
          const _SectionHeading(
              title: 'Recent transactions', trailing: 'Demo activity'),
          const SizedBox(height: 12),
          ...this.transactions.map((transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionCard(transaction: transaction),
              )),
          const SizedBox(height: 12),
          const _DemoNotice(),
        ],
      );
}

class _TransactionsScreen extends StatelessWidget {
  const _TransactionsScreen({
    required this.transactions,
    required this.onAdd,
  });

  final List<MoneyTransaction> transactions;
  final ValueChanged<MoneyTransaction> onAdd;

  Future<void> _showAddTransaction(BuildContext context) async {
    final transaction = await showDialog<MoneyTransaction>(
      context: context,
      builder: (_) => const _AddTransactionDialog(),
    );
    if (transaction != null) onAdd(transaction);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F7FC),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddTransaction(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add transaction'),
        ),
        body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Activity',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Your recorded activity across linked accounts.',
              style: TextStyle(color: Color(0xFF817B91))),
          const SizedBox(height: 20),
          const _DemoNotice(),
          const SizedBox(height: 16),
          ...transactions.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionCard(transaction: item),
              )),
        ],
      ),
      );
}

class _InsightsScreen extends StatelessWidget {
  const _InsightsScreen({required this.transactions});
  final List<MoneyTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final income = transactions
        .where((item) => item.income)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final expenses = transactions
        .where((item) => !item.income)
        .fold<double>(0, (sum, item) => sum + item.amount);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Insights',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('A simple view of the sample transactions.',
            style: TextStyle(color: Color(0xFF817B91))),
        const SizedBox(height: 20),
        _InsightTile(
          title: 'Recorded income',
          amount: income,
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF16845B),
        ),
        const SizedBox(height: 12),
        _InsightTile(
          title: 'Recorded expenses',
          amount: expenses,
          icon: Icons.trending_down_rounded,
          color: const Color(0xFFB34D61),
        ),
        const SizedBox(height: 12),
        _InsightTile(
          title: 'Net activity',
          amount: income - expenses,
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF7563D8),
        ),
        const SizedBox(height: 16),
        const _DemoNotice(),
      ],
    );
  }
}

class _AddTransactionDialog extends StatefulWidget {
  const _AddTransactionDialog({super.key});

  @override
  State<_AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<_AddTransactionDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController(text: 'General');
  bool _isIncome = false;
  String _account = accounts.first.mask;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final category = _categoryController.text.trim();
    if (title.isEmpty || amount == null || amount <= 0 || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title, category and valid amount.')),
      );
      return;
    }
    Navigator.of(context).pop(MoneyTransaction(
      title: title,
      category: category,
      when: 'Just now',
      amount: amount,
      source: 'Manual entry',
      account: _account,
      income: _isIncome,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add transaction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Expense')),
                  ButtonSegment(value: true, label: Text('Income')),
                ],
                selected: {_isIncome},
                onSelectionChanged: (value) =>
                    setState(() => _isIncome = value.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _account,
                decoration: const InputDecoration(
                  labelText: 'Bank account',
                  border: OutlineInputBorder(),
                ),
                items: accounts
                    .map((account) => DropdownMenuItem(
                          value: account.mask,
                          child: Text(account.mask),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _account = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.10),
            child: Icon(icon, color: color),
          ),
          title: Text(title),
          trailing: Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      );
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Settings',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Manage your MoneyMesh preferences.',
              style: TextStyle(color: Color(0xFF817B91))),
          const SizedBox(height: 20),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.account_balance_outlined),
                  title: Text('Bank accounts'),
                  subtitle: Text('Account management is coming next'),
                ),
                Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.link_rounded),
                  title: Text('Payment app links'),
                  subtitle: Text('Tracking only — no payments supported'),
                ),
                Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.lock_outline_rounded),
                  title: Text('Privacy & security'),
                  subtitle: Text('Your financial credentials are never requested'),
                ),
                Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('About MoneyMesh'),
                  subtitle: Text('All Your Money in One Place.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _DemoNotice(),
        ],
      );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text('Combined balance',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            '₹${total.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 13),
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 15, color: Colors.white70),
              SizedBox(width: 6),
              Text('Sum of unique bank accounts',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          if (trailing != null)
            Text(trailing!,
                style: const TextStyle(
                    color: Color(0xFF817B91),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
        ],
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});
  final BankAccount account;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: account.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.account_balance_rounded, color: account.color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(account.mask,
                        style: const TextStyle(
                            color: Color(0xFF817B91), fontSize: 11)),
                  ],
                ),
              ),
              Text('₹${account.balance.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
        ),
      );
}

class _PaymentAppsCard extends StatelessWidget {
  const _PaymentAppsCard();

  @override
  Widget build(BuildContext context) {
    const apps = [
      ('G', 'Google Pay', '2 linked accounts', Color(0xFF4285F4)),
      ('P', 'PhonePe', '2 linked accounts', Color(0xFF673AB7)),
      ('₹', 'Paytm', '1 linked account', Color(0xFF1689C7)),
    ];
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < apps.length; i++) ...[
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
              leading: CircleAvatar(
                backgroundColor: apps[i].$4.withValues(alpha: 0.10),
                child: Text(apps[i].$1,
                    style: TextStyle(
                        color: apps[i].$4, fontWeight: FontWeight.w800)),
              ),
              title: Text(apps[i].$2,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(apps[i].$3),
              trailing: const Icon(Icons.link_rounded,
                  size: 18, color: Color(0xFF8D879B)),
            ),
            if (i != apps.length - 1)
              const Divider(height: 1, indent: 70, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});
  final MoneyTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.income
        ? const Color(0xFF16845B)
        : const Color(0xFF363243);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFF0EEFA),
              child: Icon(
                transaction.income
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: const Color(0xFF7563D8),
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${transaction.category} • ${transaction.when}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF817B91))),
                  const SizedBox(height: 4),
                  Text('${transaction.source} · ${transaction.account}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF817B91))),
                ],
              ),
            ),
            Text(
              '${transaction.income ? '+' : '−'}₹${transaction.amount.toStringAsFixed(0)}',
              style: TextStyle(color: amountColor, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

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
            Icon(Icons.info_outline_rounded,
                color: Color(0xFF9B6A18), size: 18),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Sample dashboard data only. No live bank or payment-app connection is active.',
                style: TextStyle(
                    color: Color(0xFF795820), fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFECE8FF),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded), label: 'Insights'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      );
}
