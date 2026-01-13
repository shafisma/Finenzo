import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()(); // Cash, bKash, Nagad, Rocket, Bank
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  IntColumn get profileId => integer().references(Profiles, #id)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get iconCode => integer()();
  IntColumn get colorValue => integer()();
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))(); // true = expense, false = income
  IntColumn get profileId => integer().references(Profiles, #id)();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get walletId => integer().references(Wallets, #id)();
  TextColumn get receiptPath => text().nullable()();
  IntColumn get profileId => integer().references(Profiles, #id)();
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();
  TextColumn get period => text()(); // Weekly, Monthly
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  IntColumn get profileId => integer().references(Profiles, #id)();
}

class SmsPatterns extends Table {
    IntColumn get id => integer().autoIncrement()();
    TextColumn get sender => text()(); // e.g., bKash, 16216
    TextColumn get regexPattern => text()(); // Regex to extract amount
    IntColumn get targetWalletId => integer().nullable().references(Wallets, #id)();
    IntColumn get profileId => integer().references(Profiles, #id)();
}

@DriftDatabase(tables: [Profiles, Wallets, Categories, Transactions, Budgets, SmsPatterns])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Profiles
  Future<int> createProfile(ProfilesCompanion profile) => into(profiles).insert(profile);
  Future<List<Profile>> getAllProfiles() => select(profiles).get();
  
  // Wallets
  Future<int> createWallet(WalletsCompanion wallet) => into(wallets).insert(wallet);
  Future<List<Wallet>> getWalletsForProfile(int profileId) => 
      (select(wallets)..where((t) => t.profileId.equals(profileId))).get();

  // Transactions with Balance Update
  Future<void> addTransactionWithBalance(TransactionsCompanion entry) async {
    return transaction(() async {
      await into(transactions).insert(entry);
      
      // Update Wallet Balance
      final wallet = await (select(wallets)..where((tbl) => tbl.id.equals(entry.walletId.value))).getSingle();
      final category = await (select(categories)..where((tbl) => tbl.id.equals(entry.categoryId.value))).getSingle();
      
      double newBalance = wallet.balance;
      if (category.isExpense) {
        newBalance -= entry.amount.value;
      } else {
        newBalance += entry.amount.value;
      }
      
      await (update(wallets)..where((t) => t.id.equals(wallet.id))).write(WalletsCompanion(balance: Value(newBalance)));
    });
  }
  
  Future<void> seedDefaults() async {
    // Seed Profile
    final allProfiles = await select(profiles).get();
    if (allProfiles.isEmpty) {
      await createProfile(const ProfilesCompanion(name: Value('Default'), isActive: Value(true)));
    }
    
    // Seed Categories
    final allCategories = await select(categories).get();
    if (allCategories.isEmpty) {
       final List<String> defaultExpenses = ['Food', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Other'];
       for (var name in defaultExpenses) {
          await into(categories).insert(CategoriesCompanion(
              name: Value(name),
              iconCode: const Value(0), 
              colorValue: const Value(0xFFF44336), 
              isExpense: const Value(true),
              profileId: const Value(1)
          ));
       }
       
       final List<String> defaultIncome = ['Salary', 'Business', 'Gift', 'Other'];
       for (var name in defaultIncome) {
           await into(categories).insert(CategoriesCompanion(
              name: Value(name),
              iconCode: const Value(0), 
              colorValue: const Value(0xFF4CAF50), 
              isExpense: const Value(false),
              profileId: const Value(1)
          ));
       }
    }
    
    // Seed SMS Patterns
    final allPatterns = await select(smsPatterns).get();
    if (allPatterns.isEmpty) {
        await into(smsPatterns).insert(const SmsPatternsCompanion(
            sender: Value('bKash'),
            regexPattern: Value(r'Tk\s*([\d,]+\.?\d*)'), // Capture amount after Tk
            profileId: Value(1)
        ));
         await into(smsPatterns).insert(const SmsPatternsCompanion(
            sender: Value('Nagad'),
            regexPattern: Value(r'Tk\s*([\d,]+\.?\d*)'),
            profileId: Value(1)
        ));
         await into(smsPatterns).insert(const SmsPatternsCompanion(
            sender: Value('16216'), // DBBL
            regexPattern: Value(r'Tk\s*([\d,]+\.?\d*)'),
            profileId: Value(1)
        ));
    }
  }
  
  // Analytics Helpers
  Future<List<Map<String, dynamic>>> getCategoryExpenses(int profileId) async {
      final query = select(transactions).join([
        innerJoin(categories, categories.id.equalsExp(transactions.categoryId))
      ]);
      query.where(transactions.profileId.equals(profileId) & categories.isExpense.equals(true));

      final result = await query.map((rows) {
        return {
          'name': rows.readTable(categories).name,
          'amount': rows.readTable(transactions).amount,
          'color': rows.readTable(categories).colorValue,
        };
      }).get();

      // Group locally
      final Map<String, double> groupedAmounts = {};
      final Map<String, int> groupedColors = {};

      for (var row in result) {
        final name = row['name'] as String;
        final amount = row['amount'] as double;
        final color = row['color'] as int;
        
        groupedAmounts[name] = (groupedAmounts[name] ?? 0) + amount;
        groupedColors[name] = color;
      }
      
      return groupedAmounts.entries.map((e) => {
        'name': e.key,
        'amount': e.value,
        'color': groupedColors[e.key]
      }).toList();
  }
  
  Future<List<Map<String, dynamic>>> getDailyExpenses(int profileId) async {
       // Get all expenses
       final query = select(transactions).join([
        innerJoin(categories, categories.id.equalsExp(transactions.categoryId))
      ]);
      query.where(transactions.profileId.equals(profileId) & categories.isExpense.equals(true));
      query.orderBy([OrderingTerm.asc(transactions.date)]);
      
      final result = await query.map((rows) {
          return {
              'date': rows.readTable(transactions).date,
              'amount': rows.readTable(transactions).amount
          };
      }).get();
      
      final Map<DateTime, double> grouped = {};
      for (var row in result) {
          final date = row['date'] as DateTime;
          // Normalize date to YYYY-MM-DD
          final normalized = DateTime(date.year, date.month, date.day);
          final amount = row['amount'] as double;
          grouped[normalized] = (grouped[normalized] ?? 0) + amount;
      }
      
      return grouped.entries.map((e) => {
          'date': e.key,
          'amount': e.value
      }).toList();
  }

}


LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
