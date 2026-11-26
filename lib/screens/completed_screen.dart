import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/credit_record.dart';
import '../theme/app_theme.dart';

class CompletedScreen extends StatefulWidget {
  const CompletedScreen({super.key});

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen> {
  int _tab = 0; // 0 = Given Completed, 1 = Bought Completed
  List<LentRecord> _lentCompleted = [];
  List<BorrowedRecord> _borrowedCompleted = [];
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
        ApiClient.instance.fetchLent(status: 'COMPLETED'),
        ApiClient.instance.fetchBorrowed(status: 'COMPLETED'),
      ]);
      if (mounted) {
        final lentRes = results[0] as ({double totalAmount, List<LentGroup> groups, List<LentRecord> items});
        final borrowedRes = results[1] as ({double totalAmount, List<BorrowedRecord> items});
        setState(() {
          _lentCompleted = lentRes.items;
          _borrowedCompleted = borrowedRes.items;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Given Completed')),
              ButtonSegment(value: 1, label: Text('Bought Completed')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
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
          else if (_tab == 0)
            _lentCompleted.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'No completed given payments yet.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                : Column(
                    children: _lentCompleted
                        .map(
                          (item) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.accent,
                              ),
                              title: Text(
                                '${item.personName} (+${item.phoneNumber})',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                'Given: ${DateFormat('dd MMM yyyy').format(item.givenDate)}'
                                '${item.completedAt != null ? ' • Paid: ${DateFormat('dd MMM').format(item.completedAt!.toLocal())}' : ''}',
                                style: const TextStyle(color: AppTheme.textMuted),
                              ),
                              trailing: Text(
                                currency.format(item.amount),
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  )
          else if (_borrowedCompleted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No completed bought payments yet.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            )
          else
            Column(
              children: _borrowedCompleted
                  .map(
                    (item) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.accent,
                        ),
                        title: Text(
                          item.personName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Bought: ${DateFormat('dd MMM yyyy').format(item.boughtDate)}'
                          '${item.completedAt != null ? ' • Paid: ${DateFormat('dd MMM').format(item.completedAt!.toLocal())}' : ''}',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        trailing: Text(
                          currency.format(item.amount),
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
