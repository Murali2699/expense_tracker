import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      '$dbPath/spendwise_offline.db',
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE cached_expenses (
            id TEXT PRIMARY KEY,
            expense_date TEXT NOT NULL,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            note TEXT NOT NULL,
            has_screenshot INTEGER NOT NULL DEFAULT 0,
            source TEXT NOT NULL DEFAULT 'MANUAL',
            needs_review INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE cached_auto (
            id TEXT PRIMARY KEY,
            expense_date TEXT NOT NULL,
            amount REAL NOT NULL,
            merchant TEXT NOT NULL,
            source_hash TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> replaceExpensesCache(List<Expense> items) async {
    final database = await db;
    final batch = database.batch();
    batch.delete('cached_expenses', where: "id NOT LIKE 'local_%'");
    for (final e in items) {
      batch.insert(
        'cached_expenses',
        {
          'id': e.id,
          'expense_date': DateFormat('yyyy-MM-dd').format(e.expenseDate),
          'category': e.category,
          'amount': e.amount,
          'note': e.note,
          'has_screenshot': e.hasScreenshot ? 1 : 0,
          'source': e.source,
          'needs_review': e.needsReview ? 1 : 0,
          'created_at': e.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertLocalExpense(Expense e) async {
    final database = await db;
    await database.insert(
      'cached_expenses',
      {
        'id': e.id,
        'expense_date': DateFormat('yyyy-MM-dd').format(e.expenseDate),
        'category': e.category,
        'amount': e.amount,
        'note': e.note,
        'has_screenshot': e.hasScreenshot ? 1 : 0,
        'source': e.source,
        'needs_review': e.needsReview ? 1 : 0,
        'created_at': e.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCachedExpense(String id) async {
    final database = await db;
    await database.delete('cached_expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<({List<Expense> expenses, ExpenseSummary summary})> getCachedExpenses({
    DateTime? from,
    DateTime? to,
    String? category,
  }) async {
    final database = await db;
    final where = <String>[];
    final args = <Object?>[];
    final fmt = DateFormat('yyyy-MM-dd');

    if (from != null) {
      where.add('expense_date >= ?');
      args.add(fmt.format(from));
    }
    if (to != null) {
      where.add('expense_date <= ?');
      args.add(fmt.format(to));
    }
    if (category != null && category.isNotEmpty) {
      where.add('LOWER(category) = LOWER(?)');
      args.add(category.trim());
    }

    final rows = await database.query(
      'cached_expenses',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'expense_date DESC, created_at DESC',
    );

    final list = rows
        .map(
          (r) => Expense(
            id: r['id'] as String,
            expenseDate: DateTime.parse(r['expense_date'] as String),
            category: r['category'] as String,
            amount: (r['amount'] as num).toDouble(),
            note: (r['note'] as String?) ?? '',
            hasScreenshot: (r['has_screenshot'] as int? ?? 0) == 1,
            source: (r['source'] as String?) ?? 'MANUAL',
            needsReview: (r['needs_review'] as int? ?? 0) == 1,
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
        )
        .toList();

    final catMap = <String, ({double total, int count})>{};
    double totalAmount = 0;
    for (final e in list) {
      totalAmount += e.amount;
      final cur = catMap[e.category] ?? (total: 0.0, count: 0);
      catMap[e.category] = (total: cur.total + e.amount, count: cur.count + 1);
    }
    final byCategory = catMap.entries
        .map(
          (e) => CategorySummary(
            category: e.key,
            totalAmount: (e.value.total * 100).roundToDouble() / 100,
            count: e.value.count,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return (
      expenses: list,
      summary: ExpenseSummary(
        totalAmount: (totalAmount * 100).roundToDouble() / 100,
        count: list.length,
        byCategory: byCategory,
      ),
    );
  }

  Future<void> replaceAutoCache(List<Expense> items) async {
    final database = await db;
    final batch = database.batch();
    batch.delete('cached_auto', where: "id NOT LIKE 'local_%'");
    for (final e in items) {
      batch.insert(
        'cached_auto',
        {
          'id': e.id,
          'expense_date': DateFormat('yyyy-MM-dd').format(e.expenseDate),
          'amount': e.amount,
          'merchant': e.note,
          'source_hash': e.id,
          'created_at': e.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertLocalAuto({
    required String id,
    required DateTime expenseDate,
    required double amount,
    required String merchant,
    required String sourceHash,
  }) async {
    final database = await db;
    await database.insert(
      'cached_auto',
      {
        'id': id,
        'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
        'amount': amount,
        'merchant': merchant,
        'source_hash': sourceHash,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteCachedAuto(String id) async {
    final database = await db;
    await database.delete('cached_auto', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Expense>> getCachedAutoExpenses() async {
    final database = await db;
    final rows = await database.query(
      'cached_auto',
      orderBy: 'expense_date DESC, created_at DESC',
    );
    return rows
        .map(
          (r) => Expense(
            id: r['id'] as String,
            expenseDate: DateTime.parse(r['expense_date'] as String),
            category: 'Uncategorized',
            amount: (r['amount'] as num).toDouble(),
            note: (r['merchant'] as String?) ?? '',
            hasScreenshot: false,
            source: 'AUTO',
            needsReview: true,
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> enqueueSync(String action, Map<String, dynamic> payload) async {
    final database = await db;
    await database.insert('sync_queue', {
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final database = await db;
    return database.query('sync_queue', orderBy: 'id ASC');
  }

  Future<void> removeSyncItem(int id) async {
    final database = await db;
    await database.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final database = await db;
    await database.delete('cached_expenses');
    await database.delete('cached_auto');
    await database.delete('sync_queue');
  }
}
