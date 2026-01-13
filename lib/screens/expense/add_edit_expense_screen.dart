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
  
  // Hardcoded amounts for fast entry
  // ৳20, ৳50, ৳100
  final List<double> _presets = [20, 50, 100];

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final profileId = Provider.of<ProfileProvider>(context).currentProfileId;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Amount
             TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (৳)',
                border: OutlineInputBorder(),
                prefixText: '৳',
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Presets
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _presets.map((amount) => ActionChip(
                label: Text('৳${amount.toInt()}'),
                onPressed: () {
                  _amountController.text = amount.toStringAsFixed(0);
                },
              )).toList(),
            ),
             const SizedBox(height: 20),
             
             // Date
             ListTile(
               title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
               trailing: const Icon(Icons.calendar_today),
               onTap: () async {
                 final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                 );
                 if (picked != null) {
                   setState(() => _selectedDate = picked);
                 }
               },
             ),

            // Wallet
            StreamBuilder<List<Wallet>>(
              stream: (db.select(db.wallets)..where((t) => t.profileId.equals(profileId))).watch(),
              builder: (context, snapshot) {
                 final wallets = snapshot.data ?? [];
                 return DropdownButtonFormField<int>(
                   value: _selectedWalletId,
                   decoration: const InputDecoration(labelText: 'Wallet'),
                   items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text('${w.name} (${w.type})'))).toList(),
                   onChanged: (val) => setState(() => _selectedWalletId = val),
                 );
              }
            ),

            // Category
            StreamBuilder<List<Category>>(
              stream: (db.select(db.categories)..where((t) => t.profileId.equals(profileId))).watch(),
              builder: (context, snapshot) {
                 final cats = snapshot.data ?? [];
                 return DropdownButtonFormField<int>(
                   value: _selectedCategoryId,
                   decoration: const InputDecoration(labelText: 'Category'),
                   items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                   onChanged: (val) => setState(() => _selectedCategoryId = val),
                 );
              }
            ),
            
            // Note
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                 if (_amountController.text.isEmpty || _selectedWalletId == null || _selectedCategoryId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
                    return;
                 }
                 
                 final amount = double.tryParse(_amountController.text) ?? 0.0;
                 
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
              child: const Text('Save Transaction'),
            ),

          ],
        ),
      ),
    );
  }
}
