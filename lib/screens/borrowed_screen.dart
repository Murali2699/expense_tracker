import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/contact_picker.dart';
import '../core/upi_launcher.dart';
import '../models/credit_record.dart';
import '../theme/app_theme.dart';

class BorrowedScreen extends StatefulWidget {
  const BorrowedScreen({super.key});

  @override
  State<BorrowedScreen> createState() => _BorrowedScreenState();
}

class _BorrowedScreenState extends State<BorrowedScreen> {
  double _totalPending = 0;
  List<BorrowedRecord> _items = [];
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
      final res = await ApiClient.instance.fetchBorrowed(status: 'PENDING');
      if (mounted) {
        setState(() {
          _totalPending = res.totalAmount;
          _items = res.items;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddSheet({BorrowedRecord? existing}) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddBorrowedSheet(existing: existing),
    );
    if (added == true) await _load();
  }

  Future<void> _markDone(String id) async {
    try {
      await ApiClient.instance.completeBorrowed(id);
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
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('I Bought', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  colors: [Color(0xFF2B181A), Color(0xFF131A22)],
                ),
                border: Border.all(color: const Color(0xFF5B2529)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Bought on Credit (Pending)',
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
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'No pending credit purchases.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ..._items.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.personName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat('dd MMM yyyy').format(item.boughtDate)}'
                                    '${item.phoneNumber.isNotEmpty ? ' • +${item.phoneNumber}' : ''}'
                                    '${item.note.isNotEmpty ? ' • ${item.note}' : ''}',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currency.format(item.amount),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
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
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => UpiLauncher.showPaySheet(
                                  context,
                                  payeeName: item.personName,
                                  phoneOrUpi: item.phoneNumber,
                                  amount: item.amount,
                                ),
                                icon: const Icon(Icons.payment_rounded, size: 16),
                                label: const Text('Pay Now'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accent,
                                  side: const BorderSide(color: AppTheme.accent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _markDone(item.id),
                                icon: const Icon(Icons.check_rounded, size: 16),
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

class _AddBorrowedSheet extends StatefulWidget {
  const _AddBorrowedSheet({this.existing});
  final BorrowedRecord? existing;

  @override
  State<_AddBorrowedSheet> createState() => _AddBorrowedSheetState();
}

class _AddBorrowedSheetState extends State<_AddBorrowedSheet> {
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
      _date = ex.boughtDate;
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
        await ApiClient.instance.updateBorrowed(
          id: widget.existing!.id,
          personName: _nameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          boughtDate: _date,
          amount: amount,
          note: _noteCtrl.text.trim(),
        );
      } else {
        await ApiClient.instance.createBorrowed(
          personName: _nameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          boughtDate: _date,
          amount: amount,
          note: _noteCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
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
                'Bought From Someone',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Person / Shop Name',
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number (optional)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Pick from Contacts',
                    icon: const Icon(Icons.contacts_rounded, color: AppTheme.accent),
                    onPressed: _pickContact,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
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
