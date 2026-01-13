import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../providers/profile_provider.dart';

import 'add_edit_wallet_screen.dart';

class WalletListScreen extends StatefulWidget {
  const WalletListScreen({super.key});
  
  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final profileId = Provider.of<ProfileProvider>(context).currentProfileId; 

    return Scaffold(
      appBar: AppBar(title: const Text('Wallets')),
      body: StreamBuilder<List<Wallet>>(
        // Using stream for real-time updates
        stream: (db.select(db.wallets)..where((t) => t.profileId.equals(profileId))).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final wallets = snapshot.data ?? [];
          if (wallets.isEmpty) {
            return const Center(child: Text('No wallets found. Add one!'));
          }
          return ListView.builder(
            itemCount: wallets.length,
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet)),
                title: Text(wallet.name),
                subtitle: Text(wallet.type),
                trailing: Text('৳${wallet.balance.toStringAsFixed(2)}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddEditWalletScreen(wallet: wallet)),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditWalletScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
