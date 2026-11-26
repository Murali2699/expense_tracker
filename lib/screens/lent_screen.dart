import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/contact_picker.dart';
import '../core/whatsapp_helper.dart';
import '../models/credit_record.dart';
import '../theme/app_theme.dart';

class LentScreen extends StatefulWidget {
  const LentScreen({super.key});

  @override
  State<LentScreen> createState() => _LentScreenState();
}

class _LentScreenState extends State<LentScreen> {
  double _totalPending = 0;
  List<LentGroup> _groups = [];
  String _upiId = '';
  String _myPhone = '';
  bool _hasQr = false;
  bool _uploadingQr = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.fetchLent(status: 'PENDING'),
        ApiClient.instance.fetchUpiInfo(),
      ]);
      final res = results[0] as ({double totalAmount, List<LentGroup> groups});
      final upiInfo = results[1] as ({String upiId, bool hasQr, String phoneNumber});
      if (mounted) {
        setState(() {
          _totalPending = res.totalAmount;
          _groups = res.groups;
          _upiId = upiInfo.upiId;
          _hasQr = upiInfo.hasQr;
          _myPhone = upiInfo.phoneNumber;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddSheet({LentRecord? existing}) async {
    final addedPhone = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddLentSheet(existing: existing),
    );

    if (addedPhone != null && mounted) {
      await _load();
      if (existing != null || !mounted) return;
      final sendNow = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text('Send WhatsApp Reminder?'),
          content: const Text(
            'Do you want to send a WhatsApp reminder with the amount, date, and your UPI QR now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send Reminder'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: const Color(0xFF032318),
              ),
            ),
          ],
        ),
      );
      if (sendNow == true && mounted) {
        await WhatsAppHelper.sendReminder(context, phoneNumber: addedPhone);
      }
    }
  }

  Future<void> _editUpiDialog() async {
    final upiCtrl = TextEditingController(text: _upiId);
    final phoneCtrl = TextEditingController(text: _myPhone);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('My UPI & Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: upiCtrl,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'e.g. yourname@ybl',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number (for Group lookup)',
                hintText: 'e.g. 9876543210',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: const Color(0xFF032318),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      try {
        final info = await ApiClient.instance.updateUpiInfo(
          upiId: upiCtrl.text,
          phoneNumber: phoneCtrl.text,
        );
        if (mounted) {
          setState(() {
            _upiId = info.upiId;
            _myPhone = info.phoneNumber;
            _hasQr = info.hasQr;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('UPI & contact saved!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
    upiCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _uploadQr() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingQr = true);
    try {
      await ApiClient.instance.uploadQrImage(File(picked.path));
      if (mounted) {
        setState(() => _hasQr = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR image uploaded & saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Future<void> _markItemDone(String id) async {
    try {
      await ApiClient.instance.completeLent(id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _markGroupDone(String phoneNumber) async {
    try {
      await ApiClient.instance.completeLentByPhone(phoneNumber);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('I Gave', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF112A24), Color(0xFF131A22)],
                ),
                border: Border.all(color: const Color(0xFF1E4D3E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total To Receive (Pending)',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currency.format(_totalPending),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _upiId.isNotEmpty ? 'UPI: $_upiId' : 'UPI ID not set',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _hasQr
                              ? AppTheme.accent.withValues(alpha: 0.16)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _hasQr ? 'QR Ready' : 'No QR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _hasQr ? AppTheme.accent : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _editUpiDialog,
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(_upiId.isNotEmpty ? 'Edit UPI' : 'Set UPI ID'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _uploadingQr ? null : _uploadQr,
                          icon: _uploadingQr
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_rounded, size: 16),
                          label: Text(_hasQr ? 'Change QR' : 'Upload QR'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: const Color(0xFF032318),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
              )
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppTheme.danger))
            else if (_groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'No pending money given.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ..._groups.map(
                (group) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.personName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '+${group.phoneNumber}',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currency.format(group.totalAmount),
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: AppTheme.border),
                        ...group.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${DateFormat('dd MMM yyyy').format(item.givenDate)}'
                                    '${item.note.isNotEmpty ? ' • ${item.note}' : ''}',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  currency.format(item.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppTheme.textMuted,
                                    size: 19,
                                  ),
                                  onPressed: () => _openAddSheet(existing: item),
                                ),
                                IconButton(
                                  tooltip: 'Payment Done',
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppTheme.accent,
                                    size: 20,
                                  ),
                                  onPressed: () => _markItemDone(item.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => WhatsAppHelper.sendReminder(
                                  context,
                                  phoneNumber: group.phoneNumber,
                                ),
                                icon: const Icon(Icons.chat_rounded, size: 16),
                                label: const Text('WhatsApp Remind'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accent,
                                  side: const BorderSide(color: AppTheme.accent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _markGroupDone(group.phoneNumber),
                                icon: const Icon(Icons.done_all_rounded, size: 16),
                                label: const Text('Payment Done'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.accentSoft,
                                  foregroundColor: AppTheme.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddLentSheet extends StatefulWidget {
  const _AddLentSheet({this.existing});
  final LentRecord? existing;

  @override
  State<_AddLentSheet> createState() => _AddLentSheetState();
}

class _AddLentSheetState extends State<_AddLentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _nameCtrl.text = ex.personName;
      _phoneCtrl.text = ex.phoneNumber;
      _amountCtrl.text = ex.amount.toStringAsFixed(2);
      _noteCtrl.text = ex.note;
      _date = ex.givenDate;
    }
    _dateCtrl.text = DateFormat('dd MMM yyyy').format(_date);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      final picked = await ContactPicker.pick();
      if (picked == null || !mounted) return;
      setState(() {
        if (_nameCtrl.text.trim().isEmpty && picked.name.isNotEmpty) {
          _nameCtrl.text = picked.name;
        }
        if (picked.phone.isNotEmpty) {
          _phoneCtrl.text = picked.phone;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick contact: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateCtrl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      if (widget.existing != null) {
        await ApiClient.instance.updateLent(
          id: widget.existing!.id,
          personName: _nameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          givenDate: _date,
          amount: amount,
          note: _noteCtrl.text.trim(),
        );
        if (mounted) Navigator.pop(context, _phoneCtrl.text.trim());
      } else {
        final saved = await ApiClient.instance.createLent(
          personName: _nameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          givenDate: _date,
          amount: amount,
          note: _noteCtrl.text.trim(),
        );
        if (mounted) Navigator.pop(context, saved.phoneNumber);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Money Given',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Person Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Pick from Contacts',
                    icon: const Icon(Icons.contacts_rounded, color: AppTheme.accent),
                    onPressed: _pickContact,
                  ),
                ),
                validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 8)
                    ? 'Enter valid phone number'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Given',
                  prefixText: '₹ ',
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  return (n == null || n <= 0) ? 'Enter amount > 0' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                  suffixIcon: Icon(Icons.edit_calendar_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: const Color(0xFF032318),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
