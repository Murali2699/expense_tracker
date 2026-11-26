import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/expense.dart';
import '../providers/expense_controller.dart';
import '../theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({
    super.key,
    required this.controller,
    this.existing,
  });

  final ExpenseController controller;
  final Expense? existing;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _customCategoryCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _picker = ImagePicker();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = kDefaultCategories.first.name;
  File? _screenshot;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _selectedDate = ex.expenseDate;
      _amountCtrl.text = ex.amount.toStringAsFixed(2);
      _noteCtrl.text = ex.note;
      final known = kDefaultCategories.any(
        (c) => c.name.toLowerCase() == ex.category.toLowerCase(),
      );
      if (known) {
        _selectedCategory = kDefaultCategories
            .firstWhere((c) => c.name.toLowerCase() == ex.category.toLowerCase())
            .name;
      } else if (ex.category.toLowerCase() != 'uncategorized') {
        _selectedCategory = 'Other';
        _customCategoryCtrl.text = ex.category;
      }
    }
    _dateCtrl.text = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _customCategoryCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('EEE, dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (xfile != null) {
      setState(() => _screenshot = File(xfile.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    final effectiveCategory = _selectedCategory == 'Other'
        ? _customCategoryCtrl.text.trim()
        : _selectedCategory;
    try {
      if (_isEditing && widget.existing!.needsReview) {
        await ApiClient.instance.moveAutoToExpenses(
          id: widget.existing!.id,
          expenseDate: _selectedDate,
          category: effectiveCategory,
          amount: amount,
          note: _noteCtrl.text.trim(),
        );
        await widget.controller.loadExpenses();
      } else if (_isEditing) {
        await widget.controller.updateExpense(
          id: widget.existing!.id,
          expenseDate: _selectedDate,
          category: effectiveCategory,
          amount: amount,
          note: _noteCtrl.text.trim(),
        );
      } else {
        await widget.controller.addExpense(
          expenseDate: _selectedDate,
          category: effectiveCategory,
          amount: amount,
          note: _noteCtrl.text.trim(),
          screenshot: _screenshot,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Expense' : 'Add Expense')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amount
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accent,
                    ),
                  ),
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid amount > 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date (defaults to today, always editable)
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
                const SizedBox(height: 20),

                // Category
                const Text(
                  'Category',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kDefaultCategories.map((cat) {
                    final selected = _selectedCategory == cat.name;
                    return ChoiceChip(
                      label: Text(cat.name),
                      avatar: Icon(
                        cat.icon,
                        size: 16,
                        color: selected ? AppTheme.accent : cat.color,
                      ),
                      selected: selected,
                      selectedColor: AppTheme.accentSoft,
                      backgroundColor: AppTheme.surface,
                      side: BorderSide(
                        color: selected ? AppTheme.accent : AppTheme.border,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat.name),
                    );
                  }).toList(),
                ),
                if (_selectedCategory == 'Other') ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _customCategoryCtrl,
                    maxLength: 64,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Enter Category Name',
                      hintText: 'e.g., Fuel, Rent, Gift',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                    validator: (v) {
                      if (_selectedCategory == 'Other' &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Please enter a category name';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 18),

                // Note
                TextFormField(
                  controller: _noteCtrl,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                // Screenshot attachment (new expenses only)
                if (!_isEditing) ...[
                const Text(
                  'Payment Screenshot (optional)',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (_screenshot != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _screenshot!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black87,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => setState(() => _screenshot = null),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF032318),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save Expense',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
