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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold<double>(0, (sum, account) => sum + account.balance);
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
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
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
          ...transactions.map((transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionCard(transaction: transaction),
              )),
          const SizedBox(height: 12),
          const _DemoNotice(),
        ],
      ),
      bottomNavigationBar: const _BottomNavigation(),
    );
  }
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
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: 0,
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
