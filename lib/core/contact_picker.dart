import 'package:flutter/services.dart';

class PickedContact {
  const PickedContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

class ContactPicker {
  ContactPicker._();

  static const _channel =
      MethodChannel('in.muralikrishnan.expense_tracker/contacts');

  static Future<PickedContact?> pick() async {
    final res = await _channel.invokeMapMethod<String, dynamic>('pickContact');
    if (res == null) return null;
    final name = (res['name'] as String?)?.trim() ?? '';
    final phone = (res['phone'] as String?)?.trim() ?? '';
    if (name.isEmpty && phone.isEmpty) return null;
    return PickedContact(name: name, phone: phone);
  }
}
