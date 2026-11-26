import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class ParsedDebitSms {
  const ParsedDebitSms({
    required this.amount,
    required this.date,
    required this.merchant,
    required this.sourceHash,
  });

  final double amount;
  final DateTime date;
  final String merchant;
  final String sourceHash;
}

class SmsService {
  SmsService._();
  static final SmsService instance = SmsService._();

  static const _channel =
      MethodChannel('in.muralikrishnan.expense_tracker/sms');

  bool get isSupported => Platform.isAndroid;

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    return (await _channel.invokeMethod<bool>('hasPermission')) ?? false;
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    return (await _channel.invokeMethod<bool>('requestPermission')) ?? false;
  }

  Future<List<ParsedDebitSms>> scanDebitMessages({DateTime? since}) async {
    if (!isSupported) return [];
    final sinceMs = (since ?? DateTime.now().subtract(const Duration(days: 30)))
        .millisecondsSinceEpoch;

    final rawList = await _channel.invokeListMethod<dynamic>(
      'readInbox',
      {'sinceMs': sinceMs},
    );
    if (rawList == null) return [];

    final results = <ParsedDebitSms>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final address = (item['address'] as String?) ?? '';
      final body = (item['body'] as String?) ?? '';
      final dateMs = (item['dateMs'] as num?)?.toInt() ?? 0;
      final parsed = parseDebitSms(
        address: address,
        body: body,
        dateMs: dateMs,
      );
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  static final RegExp _rejectRe = RegExp(
    r'\b(credited|credit\s+to|received|refund|cashback|deposited|otp|one\s+time\s+password|verification\s+code|declined|failed|reversed|due\s+on|minimum\s+due)\b',
    caseSensitive: false,
  );

  static final RegExp _debitRe = RegExp(
    r'\b(debited|spent|paid|sent|withdrawn|purchase|deducted|txn|upi)\b',
    caseSensitive: false,
  );

  static final RegExp _amountRe = RegExp(
    r'(?:rs\.?|inr|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _fallbackAmountRe = RegExp(
    r'(?:debited|spent|paid|sent|withdrawn|deducted)\s+(?:with|by|for|of)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _merchantRe = RegExp(
    r'(?:\b(?:to|at|towards|vpa|info[:\s])\s+)([A-Za-z0-9@._\- &]{2,40})',
    caseSensitive: false,
  );

  /// Parses ONLY outgoing/paid debit SMS messages; ignores incoming/credited/OTP SMS.
  static ParsedDebitSms? parseDebitSms({
    required String address,
    required String body,
    required int dateMs,
  }) {
    if (body.trim().isEmpty || dateMs <= 0) return null;
    if (_rejectRe.hasMatch(body)) return null;
    if (!_debitRe.hasMatch(body)) return null;

    final amtMatch =
        _amountRe.firstMatch(body) ?? _fallbackAmountRe.firstMatch(body);
    if (amtMatch == null) return null;
    final amtStr = (amtMatch.group(1) ?? '').replaceAll(',', '');
    final amount = double.tryParse(amtStr);
    if (amount == null || amount <= 0 || amount > 99999999.99) return null;

    var merchant = 'Bank/UPI Debit';
    final merchMatch = _merchantRe.firstMatch(body);
    if (merchMatch != null) {
      final raw = (merchMatch.group(1) ?? '').trim();
      final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ');
      if (cleaned.length >= 2) {
        merchant = cleaned;
      }
    }

    final hash = sha256
        .convert(utf8.encode('$address|$dateMs|$body'))
        .toString();

    return ParsedDebitSms(
      amount: amount,
      date: DateTime.fromMillisecondsSinceEpoch(dateMs),
      merchant: merchant,
      sourceHash: hash,
    );
  }
}
