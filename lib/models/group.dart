class UserLookup {
  const UserLookup({
    required this.id,
    required this.username,
    required this.phoneNumber,
  });

  final String id;
  final String username;
  final String phoneNumber;

  factory UserLookup.fromJson(Map<String, dynamic> json) {
    return UserLookup(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.username,
    required this.phoneNumber,
    required this.role,
    required this.status,
  });

  final String userId;
  final String username;
  final String phoneNumber;
  final String role;
  final String status;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: (json['userId'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'MEMBER',
      status: (json['status'] as String?) ?? 'ACCEPTED',
    );
  }
}

class ExpenseGroup {
  const ExpenseGroup({
    required this.id,
    required this.name,
    required this.myRole,
    required this.members,
  });

  final String id;
  final String name;
  final String myRole;
  final List<GroupMember> members;

  factory ExpenseGroup.fromJson(Map<String, dynamic> json) {
    final rawMembers = (json['members'] as List<dynamic>?) ?? const [];
    return ExpenseGroup(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      myRole: (json['myRole'] as String?) ?? 'MEMBER',
      members: rawMembers
          .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GroupRequest {
  const GroupRequest({
    required this.memberId,
    required this.groupId,
    required this.groupName,
    required this.invitedByUsername,
  });

  final String memberId;
  final String groupId;
  final String groupName;
  final String invitedByUsername;

  factory GroupRequest.fromJson(Map<String, dynamic> json) {
    return GroupRequest(
      memberId: (json['memberId'] as String?) ?? '',
      groupId: (json['groupId'] as String?) ?? '',
      groupName: (json['groupName'] as String?) ?? '',
      invitedByUsername: (json['invitedByUsername'] as String?) ?? 'someone',
    );
  }
}

class GroupExpense {
  const GroupExpense({
    required this.id,
    required this.userId,
    required this.username,
    required this.expenseDate,
    required this.category,
    required this.amount,
    required this.note,
  });

  final String id;
  final String userId;
  final String username;
  final DateTime expenseDate;
  final String category;
  final double amount;
  final String note;

  factory GroupExpense.fromJson(Map<String, dynamic> json) {
    return GroupExpense(
      id: (json['id'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      category: (json['category'] as String?) ?? 'Other',
      amount: (json['amount'] as num).toDouble(),
      note: (json['note'] as String?) ?? '',
    );
  }
}

class GroupUserSummary {
  const GroupUserSummary({
    required this.userId,
    required this.username,
    required this.totalAmount,
    required this.byCategory,
  });

  final String userId;
  final String username;
  final double totalAmount;
  final Map<String, double> byCategory;

  factory GroupUserSummary.fromJson(Map<String, dynamic> json) {
    final rawCat = (json['byCategory'] as Map<String, dynamic>?) ?? const {};
    return GroupUserSummary(
      userId: (json['userId'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      byCategory: rawCat.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
  }
}
