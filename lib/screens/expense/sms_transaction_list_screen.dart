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

  Future<void> _scanSms() async {
    setState(() => _isLoading = true);
    final db = Provider.of<AppDatabase>(context, listen: false);
    final profileId = Provider.of<ProfileProvider>(context, listen: false).currentProfileId;
    final results = await _smsService.scanInbox(db, profileId);
    setState(() {
      _foundTransactions = results;
      _isLoading = false;
    });
  }

  Future<void> _saveTransaction(SmsProp prop) async {
      // Need to pick a wallet and category. For now, pop dialog.

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

  List<SmsProp> get _filteredTransactions {
    if (_searchQuery.isEmpty) return _foundTransactions;
    return _foundTransactions.where((t) =>
      t.sender.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      t.amount.toString().contains(_searchQuery)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanSms,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by sender or amount...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: _isLoading
         ? const Center(child: CircularProgressIndicator())
         : _filteredTransactions.isEmpty
             ? const Center(child: Text('No relevant SMS found'))
             : ListView.builder(
                 itemCount: _filteredTransactions.length,
                 itemBuilder: (context, index) {
                     final item = _filteredTransactions[index];
                     return Card(
                         margin: const EdgeInsets.all(8),
                         child: ListTile(
                             title: Text('৳${item.amount} (${item.isExpense ? 'Expense' : 'Income'})'),
                             subtitle: Text('${item.sender}\n${DateFormat('MMM d').format(item.date)}'),
                             trailing: IconButton(
                                 icon: const Icon(Icons.check, color: Colors.green),
                                 onPressed: () => _saveTransaction(item),
                             ),
                         ),
                     );
                 },
             ),
    );
  }
}
