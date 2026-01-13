import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database.dart';

class SmsService {
  final SmsQuery _query = SmsQuery();

  bool _detectTransactionType(String body) {
    final lowerBody = body.toLowerCase();
    // Keywords indicating expense (debit)
    final expenseKeywords = ['debit', 'sent', 'payment', 'withdrew', 'deducted', 'charged', 'paid', 'purchase'];
    // Keywords indicating income (credit)
    final incomeKeywords = ['credit', 'received', 'deposit', 'credited', 'added', 'transferred in', 'salary'];

    for (var keyword in expenseKeywords) {
      if (lowerBody.contains(keyword)) return true;
    }
    for (var keyword in incomeKeywords) {
      if (lowerBody.contains(keyword)) return false;
    }
    // Default to expense if unsure
    return true;
  }

  Future<List<SmsProp>> scanInbox(AppDatabase db, int profileId, {DateTime? start, int count = 50}) async {
    var permission = await Permission.sms.status;
    if (permission.isDenied) {
      permission = await Permission.sms.request();
    }
    
    if (!permission.isGranted) {
      return [];
    }
    
    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: count, 
    );
    
    // Filter by date if start date provided
    final filteredMessages = start == null ? messages : messages.where((m) {
        return m.date != null && m.date!.isAfter(start);
    }).toList();

    // Get patterns
    final patterns = await (db.select(db.smsPatterns)..where((t) => t.profileId.equals(profileId))).get();
    
    List<SmsProp> proposedTransactions = [];
    
    for (var msg in filteredMessages) {
       final body = msg.body?.toLowerCase();
       final sender = msg.address;
       if (body == null || sender == null) continue;
       final originalBody = msg.body ?? "";

       // If patterns exist, use them. If not, try generic matching
       bool matched = false;
       for (var pattern in patterns) {
           if (sender.toLowerCase().contains(pattern.sender.toLowerCase())) {
               final regExp = RegExp(pattern.regexPattern);
               final match = regExp.firstMatch(body); // Pattern matching often assumes normalized/lower body or specific regex flags. Assuming body is okay here.
               if (match != null) {
                   String amountStr = match.group(1) ?? "0";
                   amountStr = amountStr.replaceAll(',', '');
                   final amount = double.tryParse(amountStr);
                   if (amount != null) {
                       proposedTransactions.add(SmsProp(
                           sender: sender,
                           amount: amount,
                           date: msg.date ?? DateTime.now(),
                           isExpense: _detectTransactionType(body),
                           body: originalBody,
                           targetWalletId: pattern.targetWalletId
                       ));
                       matched = true;
                   }
               }
           }
       }
       
       // Fallback generic parser for common BD banks if no custom patterns matched
       if (!matched && (sender.contains('bKash') || sender.contains('NAGAD') || sender.contains('16216'))) {
            // Case-insensitive regex for Tk/BDT
            final regExpTk = RegExp(r'(?:Tk|BDT)\.?\s*([\d,]+\.?\d*)', caseSensitive: false);
            final matchTk = regExpTk.firstMatch(originalBody);
             if (matchTk != null) {
                   String amountStr = matchTk.group(1) ?? "0";
                   amountStr = amountStr.replaceAll(',', '');
                   final amount = double.tryParse(amountStr);
                   if (amount != null) {
                       proposedTransactions.add(SmsProp(
                           sender: sender,
                           amount: amount,
                           date: msg.date ?? DateTime.now(),
                           isExpense: _detectTransactionType(originalBody),
                           body: originalBody
                       ));
                   }
             }
       }
    }
    
    return proposedTransactions;
  }
}

class SmsProp {
  final double amount;
  final String sender;
  final String body;
  final DateTime date;
  final bool isExpense;
  final int? targetWalletId;

  SmsProp({
    required this.amount, 
    required this.sender, 
    required this.body, 
    required this.date, 
    this.isExpense = true, 
    this.targetWalletId
  });
}
