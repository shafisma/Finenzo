import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import '../../database/database.dart';
import '../../providers/profile_provider.dart';

class AddEditWalletScreen extends StatefulWidget {
  final Wallet? wallet; // If null, Add mode. Else Edit mode.

  const AddEditWalletScreen({super.key, this.wallet});

  @override
  State<AddEditWalletScreen> createState() => _AddEditWalletScreenState();
}

class _AddEditWalletScreenState extends State<AddEditWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  String _selectedType = 'Cash';
  final List<String> _walletTypes = ['Cash', 'bKash', 'Nagad', 'Rocket', 'Bank', 'Other'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wallet?.name ?? '');
    _balanceController = TextEditingController(text: widget.wallet?.balance.toString() ?? '0.0');
    _selectedType = widget.wallet?.type ?? 'Cash';
    if (!_walletTypes.contains(_selectedType)) {
      _selectedType = 'Other';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _saveWallet() async {
    if (_formKey.currentState!.validate()) {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final profileId = Provider.of<ProfileProvider>(context, listen: false).currentProfileId;
      final name = _nameController.text;
      final balance = double.tryParse(_balanceController.text) ?? 0.0;
      
      if (widget.wallet == null) {
        // Create
        final companion = WalletsCompanion(
          name: drift.Value(name),
          type: drift.Value(_selectedType),
          balance: drift.Value(balance),
          profileId: drift.Value(profileId),
        );
        await db.createWallet(companion);
      } else {
        // Update
        final companion = WalletsCompanion(
          id: drift.Value(widget.wallet!.id),
          name: drift.Value(name),
          type: drift.Value(_selectedType),
          balance: drift.Value(balance),
          profileId: drift.Value(profileId),
        );
        await (db.update(db.wallets)..where((t) => t.id.equals(widget.wallet!.id))).write(companion);
      }

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wallet == null ? 'Add Wallet' : 'Edit Wallet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Wallet Name'),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _walletTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(labelText: 'Initial Balance'),
                keyboardType: TextInputType.number,
                 validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter balance';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveWallet,
                child: const Text('Save Wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
