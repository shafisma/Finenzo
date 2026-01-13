import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/sms_service.dart';
import '../../database/database.dart';
import '../../providers/profile_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

class SmsTransactionListScreen extends StatefulWidget {
  const SmsTransactionListScreen({super.key});

  @override
  State<SmsTransactionListScreen> createState() => _SmsTransactionListScreenState();
}

class _SmsTransactionListScreenState extends State<SmsTransactionListScreen> {
  final SmsService _smsService = SmsService();
  bool _isLoading = true;
  List<SmsProp> _foundTransactions = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scanSms();
  }

  Future<void> _scanSms({int days = 7}) async {
    setState(() => _isLoading = true);
    final db = Provider.of<AppDatabase>(context, listen: false);
    final profileId = Provider.of<ProfileProvider>(context, listen: false).currentProfileId;
    
    // Calculate start date
    final start = DateTime.now().subtract(Duration(days: days));
    
    // Increase count to ensure we get enough messages for the duration
    final results = await _smsService.scanInbox(db, profileId, start: start, count: days * 10);
    
    setState(() {
      _foundTransactions = results;
      _isLoading = false;
    });
  }

  void _showImportOptions() {
      showModalBottomSheet(context: context, builder: (context) {
          return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Last 30 Days'),
                      onTap: () {
                          Navigator.pop(context);
                          _scanSms(days: 30);
                      },
                  ),
                  ListTile(
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('Last Month'),
                      onTap: () {
                          Navigator.pop(context);
                           _scanSms(days: 60);
                      },
                  ),
                   ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('Sync Recent (7 days)'),
                      onTap: () {
                          Navigator.pop(context);
                           _scanSms(days: 7);
                      },
                  ),
              ],
          );
      });
  }

  Future<void> _saveTransaction(SmsProp prop) async {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final profileId = Provider.of<ProfileProvider>(context, listen: false).currentProfileId;

      // Fetch all categories (Income & Expense)
      final categories = await (db.select(db.categories)..where((t) => t.profileId.equals(profileId))).get();
      final wallets = await (db.select(db.wallets)..where((t) => t.profileId.equals(profileId))).get();

      if (!mounted) return;

      // Pre-select wallet based on targetWalletId or first
      int? selectedWallet = prop.targetWalletId ?? (wallets.isNotEmpty ? wallets.first.id : null);
      // Pre-select category based on isExpense
      int? selectedCategory = categories.where((c) => c.isExpense == prop.isExpense).isNotEmpty
          ? categories.firstWhere((c) => c.isExpense == prop.isExpense).id
          : (categories.isNotEmpty ? categories.first.id : null);
      
      await showDialog(
          context: context, 
          builder: (context) {
              int? localWallet = selectedWallet;
              int? localCategory = selectedCategory;
                            
              return AlertDialog(
                  title: const Text('Confirm Transaction'),
                  content: StatefulBuilder(
                      builder: (context, setState) {
                          return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  Text('Amount: ৳${prop.amount}'),
                                  Text('Date: ${DateFormat('yyyy-MM-dd').format(prop.date)}'),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<int>(
                                      value: localWallet,
                                      hint: const Text('Wallet'),
                                      items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                                      onChanged: (v) => setState(() => localWallet = v),
                                  ),
                                   DropdownButtonFormField<int>(
                                      value: localCategory,
                                      hint: const Text('Category'),
                                      items: categories.map((c) => DropdownMenuItem(
                                        value: c.id, 
                                        child: Text(
                                          c.name,
                                          style: TextStyle(color: c.isExpense ? Colors.red : Colors.green),
                                        ),
                                      )).toList(),
                                      onChanged: (v) => setState(() => localCategory = v),
                                  )
                              ],
                          );
                      }
                  ),
                  actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      ElevatedButton(
                          onPressed: () async {
                              if (localWallet != null && localCategory != null) {
                                  await db.addTransactionWithBalance(TransactionsCompanion(
                                      amount: drift.Value(prop.amount),
                                      date: drift.Value(prop.date),
                                      note: drift.Value(prop.sender),
                                      walletId: drift.Value(localWallet!),
                                      categoryId: drift.Value(localCategory!),
                                      profileId: drift.Value(profileId),
                                  ));
                                  if (context.mounted) Navigator.pop(context);
                              }
                          }, 
                          child: const Text('Save')
                      ),
                  ],
              );
          }
      );
      
      // Remove from list after attempted save (success or cancel doesn't strictly matter for list display logic, but assume handled)
      setState(() {
          _foundTransactions.remove(prop);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Found Transactions'),
        elevation: 0,
        actions: [
             IconButton(
                icon: const Icon(Icons.download, color: Colors.blue),
                tooltip: 'Import Options',
                onPressed: _showImportOptions,
            ),
             IconButton(
               icon: const Icon(Icons.refresh),
               onPressed: () => _scanSms(days: 7),
             ),
        ],
      ),
      body: _isLoading
         ? const Center(child: CircularProgressIndicator())
         : _foundTransactions.isEmpty
             ? Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.sms_failed_outlined, size: 64, color: Colors.grey),
                     const SizedBox(height: 16),
                     const Text('No relevant SMS found', style: TextStyle(color: Colors.grey)),
                     TextButton(onPressed: _showImportOptions, child: const Text('Try importing from history'))
                   ],
                 )
               )
             : ListView.builder(
                 itemCount: _foundTransactions.length,
                 itemBuilder: (context, index) {
                     final item = _foundTransactions[index];
                     return Card(
                         elevation: 0,
                         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         color: Theme.of(context).colorScheme.surfaceContainer,
                         child: ListTile(
                             leading: CircleAvatar(
                               backgroundColor: item.isExpense ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                               child: Icon(item.isExpense ? Icons.arrow_upward : Icons.arrow_downward, color: item.isExpense ? Colors.red : Colors.green),
                             ),
                             title: Text('৳${item.amount.toStringAsFixed(0)}'),
                             subtitle: Text('${item.sender} • ${DateFormat('MMM d, h:mm a').format(item.date)}'),
                             trailing: FilledButton.tonal(
                                 onPressed: () => _saveTransaction(item),
                                 child: const Text('Add'),
                             ),
                         ),
                     );
                 },
             ),
    );
  }
}
