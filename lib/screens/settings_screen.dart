import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../utils/app_lock_service.dart';
import '../database/database.dart';
import 'package:drift/drift.dart' as drift;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _appLockService = AppLockService();
  bool _isAppLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final locked = await _appLockService.isAppLockEnabled();
    if (mounted) setState(() => _isAppLockEnabled = locked);
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Settings'),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Profile Section
                _buildSectionHeader(context, 'Profile'),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: const Text('Current Profile'),
                  subtitle: Text(profileProvider.currentProfile?.name ?? 'Default'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showProfileSwitchDialog(context, db, profileProvider);
                  },
                ),
                
                // Security Section
                _buildSectionHeader(context, 'Security'),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('App Lock'),
                  subtitle: const Text('Require authentication to open app'),
                  value: _isAppLockEnabled,
                  onChanged: (val) async {
                    await _appLockService.setAppLock(val);
                    setState(() => _isAppLockEnabled = val);
                  },
                ),

                // Data Section
                _buildSectionHeader(context, 'Data'),
                ListTile(
                  leading: const Icon(Icons.download_outlined, color: Colors.blue),
                  title: const Text('Backup Data'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backup feature coming soon!'))
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text('Clear All Data'),
                  onTap: () {
                      showDialog(context: context, builder: (ctx) => AlertDialog(
                        title: const Text('Clear Data?'),
                        content: const Text('This will delete all transactions, wallets, and categories. This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(onPressed: () async {
                             Navigator.pop(ctx);
                             final db = Provider.of<AppDatabase>(context, listen: false);
                             await db.clearAllData();
                             
                             // Refresh profile provider to pick up the re-created default profile
                             if (context.mounted) {
                                final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
                                
                                // Get the first available profile (which was just seeded)
                                final allProfiles = await db.getAllProfiles();
                                if (allProfiles.isNotEmpty) {
                                    await profileProvider.switchProfile(allProfiles.first.id);
                                }
                                
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data cleared and reset to defaults')));
                             }
                          }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ));
                  },
                ),

                // About
                _buildSectionHeader(context, 'About'),
                ListTile(
                   leading: const Icon(Icons.info_outline),
                   title: const Text('Version'),
                   subtitle: const Text('1.0.0'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showProfileSwitchDialog(BuildContext context, AppDatabase db, ProfileProvider provider) async {
      final profiles = await db.getAllProfiles();
      
      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Switch Profile', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...profiles.map((p) => ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: Text(p.name),
                  selected: p.id == provider.currentProfileId,
                  trailing: p.id == provider.currentProfileId ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    provider.switchProfile(p.id);
                    Navigator.pop(context);
                  },
                )).toList(),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create New Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddProfileDialog(context, db, provider);
                  }
                )
              ],
            ),
          );
        }
      );
  }

  void _showAddProfileDialog(BuildContext context, AppDatabase db, ProfileProvider provider) {
      final controller = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New Profile'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Profile Name', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                 if (controller.text.isNotEmpty) {
                    final id = await db.createProfile(ProfilesCompanion(name: drift.Value(controller.text)));
                    await provider.switchProfile(id);
                    if (context.mounted) Navigator.pop(context);
                 }
              },
              child: const Text('Create'),
            )
          ],
        )
      );
  }
}
