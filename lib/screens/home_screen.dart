import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../providers/profile_provider.dart';
import 'wallet/wallet_list_screen.dart';
import 'expense/add_edit_expense_screen.dart';
import 'reports/analytics_screen.dart';
import 'expense/sms_transaction_list_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       Provider.of<AppDatabase>(context, listen: false).seedDefaults();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    
    final List<Widget> pages = [
      const _DashboardView(),
      const WalletListScreen(),
      const AnalyticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallets'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditExpenseScreen()));
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final profileId = Provider.of<ProfileProvider>(context).currentProfileId;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false, 
        actions: [
           IconButton(icon: const Icon(Icons.sms_outlined), onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SmsTransactionListScreen()));
           })
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Total Balance Card
            StreamBuilder<List<Wallet>>(
              stream: db.getWalletsForProfile(profileId).asStream(), 
              builder: (context, snapshot) {
                 return StreamBuilder<List<Wallet>>(
                   stream: (db.select(db.wallets)..where((t) => t.profileId.equals(profileId))).watch(),
                   builder: (context, walletSnap) {
                     final wallets = walletSnap.data ?? [];
                     final totalBalance = wallets.fold(0.0, (sum, w) => sum + w.balance);
                     
                     return Container(
                       width: double.infinity,
                       padding: const EdgeInsets.all(24),
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(24),
                         gradient: LinearGradient(
                           colors: [Colors.deepPurple.shade800, Colors.deepPurple.shade400],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                         ),
                         boxShadow: [
                           BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))
                         ]
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text('Total Balance', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
                           const SizedBox(height: 8),
                           Text(currencyFormat.format(totalBalance), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 20),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Row(children: [Text('**** **** ****', style: TextStyle(color: Colors.white.withOpacity(0.6)))]),
                               const Icon(Icons.credit_card, color: Colors.white70)
                             ],
                           )
                         ],
                       ),
                     );
                   }
                 );
              },
            ),

            const SizedBox(height: 20),

            // Income / Expense Summary (Current Month)
            StreamBuilder<List<TransactionWithCategory>>(
              stream: db.watchAllTransactions(profileId),
              builder: (context, snapshot) {
                final transactions = snapshot.data ?? [];
                
                double income = 0;
                double expense = 0;
                final now = DateTime.now();

                for (var t in transactions) {
                   if (t.transaction.date.year == now.year && t.transaction.date.month == now.month) {
                      if (t.category.isExpense) {
                        expense += t.transaction.amount;
                      } else {
                        income += t.transaction.amount;
                      }
                   }
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        context, 
                        title: 'Income', 
                        amount: income, 
                        color: Colors.green, 
                        icon: Icons.arrow_upward
                      )
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                       child: _buildSummaryCard(
                        context, 
                        title: 'Expense', 
                        amount: expense, 
                        color: Colors.orange, 
                        icon: Icons.arrow_downward
                      )
                    ),
                  ],
                );
              }
            ),

            const SizedBox(height: 24),
            
            // Recent Transactions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Transactions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(onPressed: (){}, child: const Text('View All')) 
              ],
            ),
            
            const SizedBox(height: 10),

             // Recent Transactions List
            StreamBuilder<List<TransactionWithCategory>>(
              stream: db.watchAllTransactions(profileId),
              builder: (context, snapshot) {
                 if (snapshot.hasError) {
                   return Center(child: Text('Error loading transactions: ${snapshot.error}'));
                 }
                 if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Center(child: CircularProgressIndicator());
                 }
                 
                 final transactions = snapshot.data ?? [];
                 if (transactions.isEmpty) {
                   return Center(child: Padding(
                     padding: const EdgeInsets.all(20.0),
                     child: Text('No transactions yet', style: TextStyle(color: theme.colorScheme.outline)),
                   ));
                 }

                 // Take top 10
                 final recent = transactions.take(10).toList();

                 return ListView.separated(
                   shrinkWrap: true,
                   physics: const NeverScrollableScrollPhysics(),
                   itemCount: recent.length,
                   separatorBuilder: (c, i) => const SizedBox(height: 12),
                   itemBuilder: (context, index) {
                     final item = recent[index];
                     final isExp = item.category.isExpense;
                     
                     return Container(
                       decoration: BoxDecoration(
                         color: theme.colorScheme.surfaceContainer,
                         borderRadius: BorderRadius.circular(16),
                       ),
                       child: ListTile(
                         leading: CircleAvatar(
                           backgroundColor: isExp ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                           child: Icon(
                             isExp ? Icons.shopping_bag_outlined : Icons.attach_money,
                             color: isExp ? Colors.orange : Colors.green,
                           ),
                         ),
                         title: Text(item.category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                         subtitle: Text('${item.wallet.name} • ${dateFormat.format(item.transaction.date)}', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                         trailing: Text(
                           '${isExp ? "-" : "+"}${currencyFormat.format(item.transaction.amount)}',
                           style: TextStyle(
                             color: isExp ? Colors.red : Colors.green,
                             fontWeight: FontWeight.bold,
                             fontSize: 16
                           ),
                         ),
                       ),
                     );
                   },
                 );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, {required String title, required double amount, required Color color, required IconData icon}) {
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(currencyFormat.format(amount), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
