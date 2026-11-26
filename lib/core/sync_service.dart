import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'api_client.dart';
import 'local_db.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _syncing = false;

  void start() {
    _sub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        flush();
      }
    });
    flush();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> flush() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final items = await LocalDb.instance.getPendingSyncItems();
      for (final row in items) {
        final queueId = row['id'] as int;
        final action = row['action'] as String;
        final payload =
            jsonDecode(row['payload'] as String) as Map<String, dynamic>;

        try {
          await _processItem(action, payload);
          await LocalDb.instance.removeSyncItem(queueId);
        } on SocketException {
          break; // Still offline; keep remaining queue intact
        } on TimeoutException {
          break;
        } catch (e) {
          if (e.toString().contains('ClientException') ||
              e.toString().contains('SocketException')) {
            break;
          }
          // Non-network validation/404 error: drop poisoned item so queue never stalls
          await LocalDb.instance.removeSyncItem(queueId);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _processItem(String action, Map<String, dynamic> p) async {
    final api = ApiClient.instance;
    switch (action) {
      case 'create_expense':
        final screenshotPath = p['screenshotPath'] as String?;
        final file = (screenshotPath != null && File(screenshotPath).existsSync())
            ? File(screenshotPath)
            : null;
        await api.sendCreateExpenseOnline(
          expenseDate: DateTime.parse(p['expenseDate'] as String),
          category: p['category'] as String,
          amount: (p['amount'] as num).toDouble(),
          note: (p['note'] as String?) ?? '',
          screenshot: file,
        );
        final localId = p['localId'] as String?;
        if (localId != null) {
          await LocalDb.instance.deleteCachedExpense(localId);
        }
      case 'update_expense':
        await api.sendUpdateExpenseOnline(
          id: p['id'] as String,
          expenseDate: DateTime.parse(p['expenseDate'] as String),
          category: p['category'] as String,
          amount: (p['amount'] as num).toDouble(),
          note: (p['note'] as String?) ?? '',
        );
      case 'delete_expense':
        await api.sendDeleteExpenseOnline(p['id'] as String);
      case 'create_auto':
        await api.sendCreateAutoOnline(
          expenseDate: DateTime.parse(p['expenseDate'] as String),
          amount: (p['amount'] as num).toDouble(),
          merchant: p['merchant'] as String,
          sourceHash: p['sourceHash'] as String,
        );
        final localId = p['localId'] as String?;
        if (localId != null) {
          await LocalDb.instance.deleteCachedAuto(localId);
        }
      case 'move_auto':
        await api.sendMoveAutoOnline(
          id: p['id'] as String,
          expenseDate: DateTime.parse(p['expenseDate'] as String),
          category: p['category'] as String,
          amount: (p['amount'] as num).toDouble(),
          note: (p['note'] as String?) ?? '',
        );
    }
  }
}
