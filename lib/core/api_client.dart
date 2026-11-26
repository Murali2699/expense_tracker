import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../config/env.dart';
import '../models/credit_record.dart';
import '../models/expense.dart';
import '../models/group.dart';
import 'local_db.dart';
import 'secure_storage.dart';
import 'sync_service.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const Duration _timeout = Duration(seconds: 12);
  final http.Client _http = http.Client();
  final SecureStorageService _storage = SecureStorageService.instance;

  Future<bool>? _refreshFuture;

  String get _baseUrl => Env.apiBaseUrl;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/login');
    final resp = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(_timeout);

    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(
        data['error'] as String? ?? 'Login failed',
        statusCode: resp.statusCode,
      );
    }

    await _storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      username: username,
    );
  }

  Future<bool> loginWithBiometricSession() async {
    final ok = await _refreshTokenSingleFlight();
    if (!ok) {
      await _storage.clearAuth();
    }
    return ok;
  }

  Future<void> logout() async {
    final accessToken = await _storage.getAccessToken();
    final refreshToken = await _storage.getRefreshToken();
    if (accessToken != null) {
      try {
        await _http
            .post(
              Uri.parse('$_baseUrl/api/v1/auth/logout'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $accessToken',
              },
              body: jsonEncode({'refreshToken': refreshToken}),
            )
            .timeout(_timeout);
      } catch (_) {
        // Always clear local tokens even if offline
      }
    }
    await _storage.clearAuth();
  }

  Future<({List<Expense> expenses, ExpenseSummary summary})> fetchExpenses({
    DateTime? from,
    DateTime? to,
    String? category,
    String? source,
  }) async {
    await SyncService.instance.flush();
    final fmt = DateFormat('yyyy-MM-dd');
    final params = <String, String>{};
    if (from != null) params['from'] = fmt.format(from);
    if (to != null) params['to'] = fmt.format(to);
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (source != null && source.isNotEmpty) params['source'] = source;

    final uri = Uri.parse('$_baseUrl/api/v1/expenses')
        .replace(queryParameters: params.isEmpty ? null : params);

    try {
      final resp = await _sendWithRefresh(
        (token) => _http
            .get(uri, headers: {'Authorization': 'Bearer $token'})
            .timeout(_timeout),
      );

      final data = _decodeJson(resp.body);
      if (resp.statusCode != 200) {
        throw ApiException(
          data['error'] as String? ?? 'Failed to load expenses',
          statusCode: resp.statusCode,
        );
      }

      final list = (data['expenses'] as List<dynamic>)
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
      final summary =
          ExpenseSummary.fromJson(data['summary'] as Map<String, dynamic>);

      if (from == null && to == null && category == null && source == null) {
        await LocalDb.instance.replaceExpensesCache(list);
      } else {
        for (final e in list) {
          await LocalDb.instance.upsertLocalExpense(e);
        }
      }
      return (expenses: list, summary: summary);
    } on SocketException {
      return LocalDb.instance.getCachedExpenses(
        from: from,
        to: to,
        category: category,
      );
    } on TimeoutException {
      return LocalDb.instance.getCachedExpenses(
        from: from,
        to: to,
        category: category,
      );
    } on http.ClientException {
      return LocalDb.instance.getCachedExpenses(
        from: from,
        to: to,
        category: category,
      );
    }
  }

  Future<Expense> createExpense({
    required DateTime expenseDate,
    required String category,
    required double amount,
    String note = '',
    File? screenshot,
  }) async {
    try {
      final created = await sendCreateExpenseOnline(
        expenseDate: expenseDate,
        category: category,
        amount: amount,
        note: note,
        screenshot: screenshot,
      );
      await LocalDb.instance.upsertLocalExpense(created);
      return created;
    } on SocketException {
      return _queueOfflineExpense(
        expenseDate: expenseDate,
        category: category,
        amount: amount,
        note: note,
        screenshot: screenshot,
      );
    } on TimeoutException {
      return _queueOfflineExpense(
        expenseDate: expenseDate,
        category: category,
        amount: amount,
        note: note,
        screenshot: screenshot,
      );
    } on http.ClientException {
      return _queueOfflineExpense(
        expenseDate: expenseDate,
        category: category,
        amount: amount,
        note: note,
        screenshot: screenshot,
      );
    }
  }

  Future<Expense> _queueOfflineExpense({
    required DateTime expenseDate,
    required String category,
    required double amount,
    required String note,
    File? screenshot,
  }) async {
    final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final localExpense = Expense(
      id: localId,
      expenseDate: expenseDate,
      category: category,
      amount: amount,
      note: note,
      hasScreenshot: screenshot != null,
      createdAt: DateTime.now(),
    );
    await LocalDb.instance.upsertLocalExpense(localExpense);
    await LocalDb.instance.enqueueSync('create_expense', {
      'localId': localId,
      'expenseDate': DateFormat('yyyy-MM-dd').format(expenseDate),
      'category': category,
      'amount': amount,
      'note': note,
      'screenshotPath': screenshot?.path,
    });
    return localExpense;
  }

  Future<Expense> sendCreateExpenseOnline({
    required DateTime expenseDate,
    required String category,
    required double amount,
    String note = '',
    File? screenshot,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(expenseDate);
    final uri = Uri.parse('$_baseUrl/api/v1/expenses');

    http.Response resp;
    if (screenshot == null) {
      resp = await _sendWithRefresh(
        (token) => _http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'expenseDate': dateStr,
                'category': category,
                'amount': amount,
                'note': note,
              }),
            )
            .timeout(_timeout),
      );
    } else {
      resp = await _sendWithRefresh((token) async {
        final req = http.MultipartRequest('POST', uri);
        req.headers['Authorization'] = 'Bearer $token';
        req.fields['expenseDate'] = dateStr;
        req.fields['category'] = category;
        req.fields['amount'] = amount.toStringAsFixed(2);
        req.fields['note'] = note;
        req.files.add(
          await http.MultipartFile.fromPath('screenshot', screenshot.path),
        );
        final streamed = await _http.send(req).timeout(const Duration(seconds: 25));
        return http.Response.fromStream(streamed);
      });
    }

    final data = _decodeJson(resp.body);
    if (resp.statusCode != 201) {
      throw ApiException(
        data['error'] as String? ?? 'Failed to save expense',
        statusCode: resp.statusCode,
      );
    }
    return Expense.fromJson(data['expense'] as Map<String, dynamic>);
  }

  Future<void> deleteExpense(String id) async {
    await LocalDb.instance.deleteCachedExpense(id);
    if (id.startsWith('local_')) return;
    try {
      await sendDeleteExpenseOnline(id);
    } on SocketException {
      await LocalDb.instance.enqueueSync('delete_expense', {'id': id});
    } on TimeoutException {
      await LocalDb.instance.enqueueSync('delete_expense', {'id': id});
    } on http.ClientException {
      await LocalDb.instance.enqueueSync('delete_expense', {'id': id});
    }
  }

  Future<void> sendDeleteExpenseOnline(String id) async {
    final uri = Uri.parse('$_baseUrl/api/v1/expenses/$id');
    final resp = await _sendWithRefresh(
      (token) => _http
          .delete(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(
        data['error'] as String? ?? 'Failed to delete expense',
        statusCode: resp.statusCode,
      );
    }
  }

  Future<List<Expense>> fetchAutoExpenses() async {
    await SyncService.instance.flush();
    final uri = Uri.parse('$_baseUrl/api/v1/auto');
    try {
      final resp = await _sendWithRefresh(
        (token) => _http
            .get(uri, headers: {'Authorization': 'Bearer $token'})
            .timeout(_timeout),
      );
      final data = _decodeJson(resp.body);
      if (resp.statusCode != 200) {
        throw ApiException(data['error'] as String? ?? 'Failed to load auto expenses');
      }
      final list = (data['expenses'] as List<dynamic>? ?? [])
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
      await LocalDb.instance.replaceAutoCache(list);
      return list;
    } on SocketException {
      return LocalDb.instance.getCachedAutoExpenses();
    } on TimeoutException {
      return LocalDb.instance.getCachedAutoExpenses();
    } on http.ClientException {
      return LocalDb.instance.getCachedAutoExpenses();
    }
  }

  Future<bool> createAutoExpense({
    required DateTime expenseDate,
    required double amount,
    required String merchant,
    required String sourceHash,
  }) async {
    try {
      return await sendCreateAutoOnline(
        expenseDate: expenseDate,
        amount: amount,
        merchant: merchant,
        sourceHash: sourceHash,
      );
    } on SocketException {
      return _queueOfflineAuto(expenseDate, amount, merchant, sourceHash);
    } on TimeoutException {
      return _queueOfflineAuto(expenseDate, amount, merchant, sourceHash);
    } on http.ClientException {
      return _queueOfflineAuto(expenseDate, amount, merchant, sourceHash);
    }
  }

  Future<bool> _queueOfflineAuto(
    DateTime expenseDate,
    double amount,
    String merchant,
    String sourceHash,
  ) async {
    final localId = 'local_$sourceHash';
    await LocalDb.instance.insertLocalAuto(
      id: localId,
      expenseDate: expenseDate,
      amount: amount,
      merchant: merchant,
      sourceHash: sourceHash,
    );
    await LocalDb.instance.enqueueSync('create_auto', {
      'localId': localId,
      'expenseDate': DateFormat('yyyy-MM-dd').format(expenseDate),
      'amount': amount,
      'merchant': merchant,
      'sourceHash': sourceHash,
    });
    return true;
  }

  Future<bool> sendCreateAutoOnline({
    required DateTime expenseDate,
    required double amount,
    required String merchant,
    required String sourceHash,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auto');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'expenseDate': DateFormat('yyyy-MM-dd').format(expenseDate),
              'amount': amount,
              'merchant': merchant,
              'sourceHash': sourceHash,
            }),
          )
          .timeout(_timeout),
    );
    if (resp.statusCode == 201) return true;
    if (resp.statusCode == 200) return false; // duplicate SMS
    final data = _decodeJson(resp.body);
    throw ApiException(data['error'] as String? ?? 'Failed to import SMS');
  }

  Future<Expense> moveAutoToExpenses({
    required String id,
    required DateTime expenseDate,
    required String category,
    required double amount,
    required String note,
  }) async {
    try {
      final moved = await sendMoveAutoOnline(
        id: id,
        expenseDate: expenseDate,
        category: category,
        amount: amount,
        note: note,
      );
      await LocalDb.instance.deleteCachedAuto(id);
      await LocalDb.instance.upsertLocalExpense(moved);
      return moved;
    } on SocketException {
      return _queueOfflineMoveAuto(id, expenseDate, category, amount, note);
    } on TimeoutException {
      return _queueOfflineMoveAuto(id, expenseDate, category, amount, note);
    } on http.ClientException {
      return _queueOfflineMoveAuto(id, expenseDate, category, amount, note);
    }
  }

  Future<Expense> _queueOfflineMoveAuto(
    String id,
    DateTime expenseDate,
    String category,
    double amount,
    String note,
  ) async {
    await LocalDb.instance.deleteCachedAuto(id);
    final moved = Expense(
      id: id.startsWith('local_') ? id : 'local_$id',
      expenseDate: expenseDate,
      category: category,
      amount: amount,
      note: note,
      hasScreenshot: false,
      source: 'AUTO',
      needsReview: false,
      createdAt: DateTime.now(),
    );
    await LocalDb.instance.upsertLocalExpense(moved);
    await LocalDb.instance.enqueueSync('move_auto', {
      'id': id,
      'expenseDate': DateFormat('yyyy-MM-dd').format(expenseDate),
      'category': category,
      'amount': amount,
      'note': note,
    });
    return moved;
  }

  Future<Expense> sendMoveAutoOnline({
    required String id,
    required DateTime expenseDate,
    required String category,
    required double amount,
    required String note,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auto/$id');
    final resp = await _sendWithRefresh(
      (token) => _http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'expenseDate': DateFormat('yyyy-MM-dd').format(expenseDate),
              'category': category,
              'amount': amount,
              'note': note,
            }),
          )
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(data['error'] as String? ?? 'Failed to move to expenses');
    }
    return Expense.fromJson(data['expense'] as Map<String, dynamic>);
  }

  Future<void> deleteAutoExpense(String id) async {
    await LocalDb.instance.deleteCachedAuto(id);
    if (id.startsWith('local_')) return;
    final uri = Uri.parse('$_baseUrl/api/v1/auto/$id');
    final resp = await _sendWithRefresh(
      (token) => _http
          .delete(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to delete auto expense');
    }
  }

  Future<Expense> updateExpense({
    required String id,
    required DateTime expenseDate,
    required String category,
    required double amount,
    required String note,
  }) async {
    try {
      final updated = await sendUpdateExpenseOnline(
        id: id,
        expenseDate: expenseDate,
        category: category,
        amount: amount,
        note: note,
      );
      await LocalDb.instance.upsertLocalExpense(updated);
      return updated;
    } on SocketException {
      return _queueOfflineUpdateExpense(id, expenseDate, category, amount, note);
    } on TimeoutException {
      return _queueOfflineUpdateExpense(id, expenseDate, category, amount, note);
    } on http.ClientException {
      return _queueOfflineUpdateExpense(id, expenseDate, category, amount, note);
    }
  }

  Future<Expense> _queueOfflineUpdateExpense(
    String id,
    DateTime expenseDate,
    String category,
    double amount,
    String note,
  ) async {
    final updated = Expense(
      id: id,
      expenseDate: expenseDate,
      category: category,
      amount: amount,
      note: note,
      hasScreenshot: false,
      createdAt: DateTime.now(),
    );
    await LocalDb.instance.upsertLocalExpense(updated);
    await LocalDb.instance.enqueueSync('update_expense', {
      'id': id,
      'expenseDate': DateFormat('yyyy-MM-dd').format(expenseDate),
      'category': category,
      'amount': amount,
      'note': note,
    });
    return updated;
  }

  Future<Expense> sendUpdateExpenseOnline({
    required String id,
    required DateTime expenseDate,
    required String category,
    required double amount,
    required String note,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/expenses/$id');
    final resp = await _sendWithRefresh(
      (token) => _http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'expenseDate': DateFormat('yyyy-MM-dd').format(expenseDate),
              'category': category,
              'amount': amount,
              'note': note,
            }),
          )
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(data['error'] as String? ?? 'Failed to update expense');
    }
    return Expense.fromJson(data['expense'] as Map<String, dynamic>);
  }

  Future<void> updateLent({
    required String id,
    required String personName,
    required String phoneNumber,
    required DateTime givenDate,
    required double amount,
    required String note,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/lent/$id');
    final resp = await _sendWithRefresh(
      (token) => _http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'personName': personName,
              'phoneNumber': phoneNumber,
              'givenDate': DateFormat('yyyy-MM-dd').format(givenDate),
              'amount': amount,
              'note': note,
            }),
          )
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to update record');
    }
  }

  Future<void> updateBorrowed({
    required String id,
    required String personName,
    required String phoneNumber,
    required DateTime boughtDate,
    required double amount,
    required String note,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/borrowed/$id');
    final resp = await _sendWithRefresh(
      (token) => _http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'personName': personName,
              'phoneNumber': phoneNumber,
              'boughtDate': DateFormat('yyyy-MM-dd').format(boughtDate),
              'amount': amount,
              'note': note,
            }),
          )
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to update record');
    }
  }

  String screenshotUrl(String expenseId) =>
      '$_baseUrl/api/v1/expenses/$expenseId/screenshot';

  Future<Map<String, String>> authHeaders() async {
    final token = await _storage.getAccessToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  // --- Lent ("I Gave") ---

  Future<({double totalAmount, List<LentGroup> groups, List<LentRecord> items})>
      fetchLent({String status = 'PENDING'}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/lent')
        .replace(queryParameters: {'status': status});
    final resp = await _sendWithRefresh(
      (token) => _http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(data['error'] as String? ?? 'Failed to load lent records');
    }
    final groups = (data['groups'] as List<dynamic>? ?? [])
        .map((e) => LentGroup.fromJson(e as Map<String, dynamic>))
        .toList();
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => LentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      groups: groups,
      items: items,
    );
  }

  Future<LentRecord> createLent({
    required String personName,
    required String phoneNumber,
    required DateTime givenDate,
    required double amount,
    String note = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/lent');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'personName': personName,
              'phoneNumber': phoneNumber,
              'givenDate': DateFormat('yyyy-MM-dd').format(givenDate),
              'amount': amount,
              'note': note,
            }),
          )
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 201) {
      throw ApiException(data['error'] as String? ?? 'Failed to save record');
    }
    return LentRecord.fromJson(data['item'] as Map<String, dynamic>);
  }

  Future<void> completeLent(String id) async {
    final uri = Uri.parse('$_baseUrl/api/v1/lent/$id/complete');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to mark completed');
    }
  }

  Future<void> completeLentByPhone(String phoneNumber) async {
    final uri = Uri.parse('$_baseUrl/api/v1/lent/complete-by-phone');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'phoneNumber': phoneNumber}),
          )
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to mark completed');
    }
  }

  Future<ReminderResult> sendWhatsAppReminder(String phoneNumber) async {
    final uri = Uri.parse('$_baseUrl/api/v1/lent/remind');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'phoneNumber': phoneNumber}),
          )
          .timeout(const Duration(seconds: 25)),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(data['error'] as String? ?? 'Failed to send reminder');
    }
    return ReminderResult.fromJson(data);
  }

  Future<({String upiId, bool hasQr, String phoneNumber})> fetchUpiInfo() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/qr/info');
      final resp = await _sendWithRefresh(
        (token) => _http
            .get(uri, headers: {'Authorization': 'Bearer $token'})
            .timeout(_timeout),
      );
      if (resp.statusCode != 200) {
        return (upiId: '', hasQr: false, phoneNumber: '');
      }
      final data = _decodeJson(resp.body);
      return (
        upiId: (data['upiId'] as String?)?.trim() ?? '',
        hasQr: (data['hasQr'] as bool?) ?? false,
        phoneNumber: (data['phoneNumber'] as String?)?.trim() ?? '',
      );
    } catch (_) {
      return (upiId: '', hasQr: false, phoneNumber: '');
    }
  }

  Future<String> fetchUpiId() async {
    final info = await fetchUpiInfo();
    return info.upiId;
  }

  Future<({String upiId, bool hasQr, String phoneNumber})> updateUpiInfo({
    required String upiId,
    String? phoneNumber,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/qr/upi');
    final payload = <String, dynamic>{'upiId': upiId.trim()};
    if (phoneNumber != null) {
      payload['phoneNumber'] = phoneNumber.trim();
    }
    final resp = await _sendWithRefresh(
      (token) => _http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(data['error'] as String? ?? 'Failed to save UPI ID');
    }
    return (
      upiId: (data['upiId'] as String?)?.trim() ?? '',
      hasQr: (data['hasQr'] as bool?) ?? false,
      phoneNumber: (data['phoneNumber'] as String?)?.trim() ?? '',
    );
  }

  Future<void> uploadQrImage(File file) async {
    final uri = Uri.parse('$_baseUrl/api/v1/qr/upload');
    final resp = await _sendWithRefresh((token) async {
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('qr', file.path));
      final streamed = await _http.send(req).timeout(const Duration(seconds: 30));
      return http.Response.fromStream(streamed);
    });
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to upload QR image');
    }
  }

  Future<File?> downloadQrToTempFile() async {
    final uri = Uri.parse('$_baseUrl/api/v1/qr');
    final resp = await _sendWithRefresh(
      (token) => _http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/upi-qr.png');
    await file.writeAsBytes(resp.bodyBytes, flush: true);
    return file;
  }

  // --- Groups ---

  Future<UserLookup> lookupUser(String username) async {
    final uri = Uri.parse('$_baseUrl/api/v1/users/lookup').replace(
      queryParameters: {'username': username.trim()},
    );
    final resp = await _sendWithRefresh(
      (token) => _http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(data['error'] as String? ?? 'User not found');
    }
    return UserLookup.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<({List<ExpenseGroup> groups, List<GroupRequest> pendingRequests})>
      fetchGroups() async {
    final uri = Uri.parse('$_baseUrl/api/v1/groups');
    final resp = await _sendWithRefresh(
      (token) => _http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(data['error'] as String? ?? 'Failed to load groups');
    }
    final groups = ((data['groups'] as List<dynamic>?) ?? const [])
        .map((e) => ExpenseGroup.fromJson(e as Map<String, dynamic>))
        .toList();
    final requests = ((data['pendingRequests'] as List<dynamic>?) ?? const [])
        .map((e) => GroupRequest.fromJson(e as Map<String, dynamic>))
        .toList();
    return (groups: groups, pendingRequests: requests);
  }

  Future<String> createGroup({
    required String name,
    String? inviteUsername,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/groups');
    final body = <String, dynamic>{'name': name.trim()};
    if (inviteUsername != null && inviteUsername.trim().isNotEmpty) {
      body['inviteUsername'] = inviteUsername.trim();
    }
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 201) {
      throw ApiException(data['error'] as String? ?? 'Failed to create group');
    }
    return (data['group'] as Map<String, dynamic>)['id'] as String;
  }

  Future<void> inviteToGroup({
    required String groupId,
    required String username,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/groups/$groupId/invite');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'username': username.trim()}),
          )
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to send request');
    }
  }

  Future<void> respondToGroupRequest({
    required String memberId,
    required String action,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/groups/requests/$memberId/respond');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'action': action}),
          )
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to respond');
    }
  }

  Future<({List<GroupExpense> expenses, double totalAmount, List<GroupUserSummary> byUser})>
      fetchGroupExpenses({
    required String groupId,
    DateTime? from,
    DateTime? to,
    String? category,
  }) async {
    final params = <String, String>{};
    final fmt = DateFormat('yyyy-MM-dd');
    if (from != null) params['from'] = fmt.format(from);
    if (to != null) params['to'] = fmt.format(to);
    if (category != null && category.trim().isNotEmpty) {
      params['category'] = category.trim();
    }
    final uri = Uri.parse('$_baseUrl/api/v1/groups/$groupId/expenses')
        .replace(queryParameters: params.isEmpty ? null : params);
    final resp = await _sendWithRefresh(
      (token) => _http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(data['error'] as String? ?? 'Failed to load group expenses');
    }
    final expenses = ((data['expenses'] as List<dynamic>?) ?? const [])
        .map((e) => GroupExpense.fromJson(e as Map<String, dynamic>))
        .toList();
    final summary = (data['summary'] as Map<String, dynamic>?) ?? const {};
    final totalAmount = (summary['totalAmount'] as num?)?.toDouble() ?? 0;
    final byUser = ((summary['byUser'] as List<dynamic>?) ?? const [])
        .map((e) => GroupUserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    return (expenses: expenses, totalAmount: totalAmount, byUser: byUser);
  }

  Future<void> addGroupExpense({
    required String groupId,
    required DateTime expenseDate,
    required String category,
    required double amount,
    String note = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/groups/$groupId/expenses');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'expenseDate': DateFormat('yyyy-MM-dd').format(expenseDate),
              'category': category.trim(),
              'amount': amount,
              'note': note.trim(),
            }),
          )
          .timeout(_timeout),
    );
    if (resp.statusCode != 201) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to add group expense');
    }
  }

  Future<void> deleteGroupExpense({
    required String groupId,
    required String expenseId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/groups/$groupId/expenses/$expenseId');
    final resp = await _sendWithRefresh(
      (token) => _http
          .delete(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to delete expense');
    }
  }

  // --- Borrowed ("I Bought From") ---

  Future<({double totalAmount, List<BorrowedRecord> items})> fetchBorrowed({
    String status = 'PENDING',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/borrowed')
        .replace(queryParameters: {'status': status});
    final resp = await _sendWithRefresh(
      (token) => _http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(data['error'] as String? ?? 'Failed to load borrowed records');
    }
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => BorrowedRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      items: items,
    );
  }

  Future<BorrowedRecord> createBorrowed({
    required String personName,
    String phoneNumber = '',
    required DateTime boughtDate,
    required double amount,
    String note = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/borrowed');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'personName': personName,
              'phoneNumber': phoneNumber,
              'boughtDate': DateFormat('yyyy-MM-dd').format(boughtDate),
              'amount': amount,
              'note': note,
            }),
          )
          .timeout(_timeout),
    );
    final data = _decodeJson(resp.body);
    if (resp.statusCode != 201) {
      throw ApiException(data['error'] as String? ?? 'Failed to save record');
    }
    return BorrowedRecord.fromJson(data['item'] as Map<String, dynamic>);
  }

  Future<void> completeBorrowed(String id) async {
    final uri = Uri.parse('$_baseUrl/api/v1/borrowed/$id/complete');
    final resp = await _sendWithRefresh(
      (token) => _http
          .post(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout),
    );
    if (resp.statusCode != 200) {
      final data = _decodeJson(resp.body);
      throw ApiException(data['error'] as String? ?? 'Failed to mark completed');
    }
  }

  Future<http.Response> _sendWithRefresh(
    Future<http.Response> Function(String token) requestFn,
  ) async {
    var token = await _storage.getAccessToken();
    if (token == null) {
      throw ApiException('Session expired. Please sign in.', statusCode: 401);
    }

    var resp = await requestFn(token);
    if (resp.statusCode == 401) {
      final refreshed = await _refreshTokenSingleFlight();
      if (!refreshed) {
        await _storage.clearAuth();
        throw ApiException('Session expired. Please sign in.', statusCode: 401);
      }
      token = await _storage.getAccessToken();
      if (token == null) {
        throw ApiException('Session expired. Please sign in.', statusCode: 401);
      }
      resp = await requestFn(token);
    }
    return resp;
  }

  Future<bool> _refreshTokenSingleFlight() {
    if (_refreshFuture != null) return _refreshFuture!;
    _refreshFuture = _doRefresh().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final resp = await _http
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);

      if (resp.statusCode != 200) return false;
      final data = _decodeJson(resp.body);
      await _storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return {};
    try {
      final parsed = jsonDecode(body);
      return parsed is Map<String, dynamic> ? parsed : {};
    } catch (_) {
      return {};
    }
  }
}
