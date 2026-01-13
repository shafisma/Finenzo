import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import '../../database/database.dart';
import '../../providers/profile_provider.dart';
import 'package:intl/intl.dart';

class AddEditExpenseScreen extends StatefulWidget {
  const AddEditExpenseScreen({super.key});

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int? _selectedWalletId;
  int? _selectedCategoryId;
  bool _isExpense = true;
  
  // Hardcoded amounts for fast entry
  // ৳20, ৳50, ৳100, ৳500
  final List<double> _presets = [20, 50, 100, 500];

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final profileId = Provider.of<ProfileProvider>(context).currentProfileId;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('New Transaction'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle Income/Expense
                  Center(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true, 
                          label: Text('Expense'), 
                          icon: Icon(Icons.arrow_downward, color: Colors.red)
                        ),
                        ButtonSegment(
                          value: false, 
                          label: Text('Income'), 
                          icon: Icon(Icons.arrow_upward, color: Colors.green)
                        ),
                      ],
                      selected: {_isExpense},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _isExpense = newSelection.first;
                          _selectedCategoryId = null; // Reset category on type switch
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) {
                             return _isExpense ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2);
                          }
                          return Colors.transparent;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Amount Display
                  Text('Amount', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: _isExpense ? Colors.red : Colors.green, 
                      fontWeight: FontWeight.bold
                    ),
                    decoration: InputDecoration(
                      hintText: '৳0',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: theme.colorScheme.outline.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.currency_bitcoin, size: 0),
                    ),
                  ),

                  // Presets
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final amount = _presets[index];
                          return ActionChip(
                            label: Text('৳${amount.toInt()}'),
                            onPressed: () {
                              _amountController.text = amount.toStringAsFixed(0);
                            },
                             backgroundColor: theme.colorScheme.surfaceContainerHighest,
                             side: BorderSide.none,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const Divider(),
                  const SizedBox(height: 16),

                  // Form Fields
                  // Wallet Selector
                  StreamBuilder<List<Wallet>>(
                    stream: (db.select(db.wallets)..where((t) => t.profileId.equals(profileId))).watch(),
                    builder: (context, snapshot) {
                      final wallets = snapshot.data ?? [];
                      if (wallets.isNotEmpty && _selectedWalletId == null) {
                         // Auto-select first wallet if none selected
                         WidgetsBinding.instance.addPostFrameCallback((_) {
                           if(mounted) setState(() => _selectedWalletId = wallets.first.id);
                         });
                      }
                      
                      return DropdownButtonFormField<int>(
                        value: _selectedWalletId,
                        decoration: InputDecoration(
                          labelText: 'Wallet',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                        ),
                        items: wallets.map((w) => DropdownMenuItem(
                          value: w.id, 
                          child: Text(w.name),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedWalletId = val),
                        validator: (value) => value == null ? 'Select a wallet' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Category Selector
                  StreamBuilder<List<Category>>(
                    stream: (db.select(db.categories)
                           ..where((t) => t.profileId.equals(profileId) & t.isExpense.equals(_isExpense)))
                           .watch(),
                    builder: (context, snapshot) {
                      final cats = snapshot.data ?? [];
                      // Don't auto-select category, let user pick.

                      return DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.category_outlined),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                        ),
                        items: cats.map((c) => DropdownMenuItem(
                          value: c.id, 
                          child: Text(c.name),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedCategoryId = val),
                         validator: (value) => value == null ? 'Select a category' : null,
                      );
                    },
                  ),
                   const SizedBox(height: 16),

                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context, 
                        initialDate: _selectedDate, 
                        firstDate: DateTime(2020), 
                        lastDate: DateTime(2030)
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerLow,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined),
                          const SizedBox(width: 12),
                          Text(DateFormat.yMMMd().format(_selectedDate), style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),

                   const SizedBox(height: 16),

                  // Note
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.edit_note),
                      filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Save Button
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () async {
                   final amount = double.tryParse(_amountController.text);
                   if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                      return;
                   }
                   if (_selectedWalletId == null || _selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select Wallet and Category')));
                      return;
                   }
                   
                   final entry = TransactionsCompanion(
                     amount: drift.Value(amount),
                     date: drift.Value(_selectedDate),
                     note: drift.Value(_noteController.text),
                     walletId: drift.Value(_selectedWalletId!),
                     categoryId: drift.Value(_selectedCategoryId!),
                     profileId: drift.Value(profileId),
                   );
                   
                   await db.addTransactionWithBalance(entry);
                   if (context.mounted) Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                child: const Text('Save Transaction'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
