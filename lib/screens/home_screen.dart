import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database.dart';
import 'wallet/wallet_list_screen.dart';
import 'expense/add_edit_expense_screen.dart';

import 'reports/analytics_screen.dart';
import 'expense/sms_transaction_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       Provider.of<AppDatabase>(context, listen: false).seedDefaults();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Wallets'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletListScreen()));
              },
            ),
             ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms),
              title: const Text('Scan SMS'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SmsTransactionListScreen()));
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Welcome to Offline Expense Tracker'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditExpenseScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
