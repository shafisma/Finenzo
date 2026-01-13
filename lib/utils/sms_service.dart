import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database.dart';

class SmsService {
  final SmsQuery _query = SmsQuery();

  Future<List<SmsProp>> scanInbox(AppDatabase db, int profileId) async {
    var permission = await Permission.sms.status;
    if (permission.isDenied) {
      permission = await Permission.sms.request();
    }
    
    if (!permission.isGranted) {
      return [];
    }
    
    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 50, // Limit to last 50 messages for speed
    );
    
    // Get patterns
    final patterns = await (db.select(db.smsPatterns)..where((t) => t.profileId.equals(profileId))).get();
    
    List<SmsProp> proposedTransactions = [];
    
    for (var msg in messages) {
       final body = msg.body;
       final sender = msg.address;
       if (body == null || sender == null) continue;
       
       for (var pattern in patterns) {
           // Basic sender matching (contains)
           if (sender.contains(pattern.sender)) {
               final regExp = RegExp(pattern.regexPattern);
               final match = regExp.firstMatch(body);
               if (match != null) {
                   final amountStr = match.group(1)?.replaceAll(',','');
                   if (amountStr != null) {
                       final amount = double.tryParse(amountStr);
                       if (amount != null) {
                           proposedTransactions.add(SmsProp(
                               amount: amount,
                               sender: sender,
                               body: body,
                               date: msg.date ?? DateTime.now()
                           ));
                       }
                   }
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
  
  SmsProp({required this.amount, required this.sender, required this.body, required this.date});
}
