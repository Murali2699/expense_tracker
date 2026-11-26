class LentRecord {
  const LentRecord({
    required this.id,
    required this.personName,
    required this.phoneNumber,
    required this.givenDate,
    required this.amount,
    required this.note,
    required this.status,
    this.completedAt,
  });

  final String id;
  final String personName;
  final String phoneNumber;
  final DateTime givenDate;
  final double amount;
  final String note;
  final String status;
  final DateTime? completedAt;

  factory LentRecord.fromJson(Map<String, dynamic> json) {
    return LentRecord(
      id: json['id'] as String,
      personName: json['personName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      givenDate: DateTime.parse(json['givenDate'] as String),
      amount: (json['amount'] as num).toDouble(),
      note: (json['note'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'PENDING',
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }
}

class LentGroup {
  const LentGroup({
    required this.personName,
    required this.phoneNumber,
    required this.totalAmount,
    required this.items,
  });

  final String personName;
  final String phoneNumber;
  final double totalAmount;
  final List<LentRecord> items;

  factory LentGroup.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? [])
        .map((e) => LentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return LentGroup(
      personName: json['personName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      items: list,
    );
  }
}

class BorrowedRecord {
  const BorrowedRecord({
    required this.id,
    required this.personName,
    required this.phoneNumber,
    required this.boughtDate,
    required this.amount,
    required this.note,
    required this.status,
    this.completedAt,
  });

  final String id;
  final String personName;
  final String phoneNumber;
  final DateTime boughtDate;
  final double amount;
  final String note;
  final String status;
  final DateTime? completedAt;

  factory BorrowedRecord.fromJson(Map<String, dynamic> json) {
    return BorrowedRecord(
      id: json['id'] as String,
      personName: json['personName'] as String,
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      boughtDate: DateTime.parse(json['boughtDate'] as String),
      amount: (json['amount'] as num).toDouble(),
      note: (json['note'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'PENDING',
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }
}

class ReminderResult {
  const ReminderResult({
    required this.mode,
    required this.sent,
    required this.phoneNumber,
    required this.message,
    required this.upiId,
    required this.hasQr,
  });

  final String mode; // 'cloud_api' or 'deeplink'
  final bool sent;
  final String phoneNumber;
  final String message;
  final String upiId;
  final bool hasQr;

  factory ReminderResult.fromJson(Map<String, dynamic> json) {
    return ReminderResult(
      mode: (json['mode'] as String?) ?? 'deeplink',
      sent: (json['sent'] as bool?) ?? false,
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      upiId: (json['upiId'] as String?) ?? '',
      hasQr: (json['hasQr'] as bool?) ?? false,
    );
  }
}
