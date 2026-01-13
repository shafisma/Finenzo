import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/database.dart';
import 'screens/home_screen.dart';

import 'utils/app_lock_service.dart';

import 'providers/profile_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check App Lock
  final appLock = AppLockService();
  bool isLocked = await appLock.isAppLockEnabled();
  bool isAuthenticated = false;

  if (isLocked) {
    isAuthenticated = await appLock.authenticate();
  } else {
    isAuthenticated = true;
  }
  
  if (!isAuthenticated) {
     // If failed, exit app or show error. For simplicity, we just exit (or could show a 'Locked' screen)
     // Since runApp hasn't run, the app essentially won't start UI if we return here.
     // Better UI: Run an app that shows "Locked"
     runApp(const LockedApp());
     return;
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>(
          create: (context) => AppDatabase(),
          dispose: (context, db) => db.close(),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (context) => ProfileProvider(Provider.of<AppDatabase>(context, listen: false)),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class LockedApp extends StatelessWidget {
  const LockedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text("Authentication Failed. Restart App.")),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}