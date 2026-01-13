import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';

class ProfileProvider extends ChangeNotifier {
  final AppDatabase _db;
  int? _currentProfileId;
  Profile? _currentProfile;

  ProfileProvider(this._db) {
    _loadCurrentProfile();
  }

  int get currentProfileId => _currentProfileId ?? 1; // Default to 1 if not loaded yet
  Profile? get currentProfile => _currentProfile;

  Future<void> _loadCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('current_profile_id') ?? 1;
    
    // Verify it exists in DB
    final profiles = await (_db.select(_db.profiles)..where((t) => t.id.equals(id))).get();
    
    if (profiles.isNotEmpty) {
      _currentProfileId = id;
      _currentProfile = profiles.first;
    } else {
      // Fallback to first profile if exists
      final allProfiles = await _db.select(_db.profiles).get();
      if (allProfiles.isNotEmpty) {
        _currentProfileId = allProfiles.first.id;
        _currentProfile = allProfiles.first;
        await prefs.setInt('current_profile_id', _currentProfileId!);
      }
    }
    notifyListeners();
  }

  Future<void> switchProfile(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    _currentProfileId = profileId;
    
    final profiles = await (_db.select(_db.profiles)..where((t) => t.id.equals(profileId))).get();
    if (profiles.isNotEmpty) {
      _currentProfile = profiles.first;
    }
    
    await prefs.setInt('current_profile_id', profileId);
    notifyListeners();
  }
}
