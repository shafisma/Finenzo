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
    final db = Provider.of<AppDatabase>(context);
    final profileId = Provider.of<ProfileProvider>(context).currentProfileId;
    final theme = Theme.of(context);

    // Date formatting
    final dateFormat = DateFormat('MMM d, y');
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
               // Settings placeholder
            },
          )
        ],
      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Total Balance Card
            StreamBuilder<List<Wallet>>(
              stream: db.getWalletsForProfile(profileId).asStream(), // Simplified, usually watch()
              // Better to watch wallets specifically if we want real-time balance updates from DB
              builder: (context, snapshot) {
                 // We actually need to watch because balance changes.
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

                 // Take top 5
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
            const SizedBox(height: 80), // Bottom padding for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditExpenseScreen()));
        },
        backgroundColor: Colors.black, // Dark accent like the design
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

  Widget _buildDrawer(BuildContext context) {
      return Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person)),
                  SizedBox(height: 10),
                  Text('Shadman', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('shadman@example.com', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
              selected: true,
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Wallets'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletListScreen()));
              },
            ),
             ListTile(
              leading: const Icon(Icons.pie_chart_outline),
              title: const Text('Analytics'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Scan SMS'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SmsTransactionListScreen()));
              },
            ),
          ],
        ),
      );
  }
}