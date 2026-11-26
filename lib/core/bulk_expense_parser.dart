class ParsedBulkExpense {
  const ParsedBulkExpense({
    required this.date,
    required this.category,
    required this.amount,
    required this.note,
  });

  final DateTime date;
  final String category;
  final double amount;
  final String note;
}

class BulkExpenseParser {
  BulkExpenseParser._();

  static const Map<String, int> _months = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  static const String _monthPattern =
      r'jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?';

  static final RegExp _dateHeaderRe = RegExp(
    '^('
    r'(\d{4})[-./](\d{1,2})[-./](\d{1,2})'
    '|'
    '(\\d{1,2})(?:st|nd|rd|th)?[\\s,./-]+($_monthPattern|\\d{1,2})[\\s,./-]+(\\d{2,4})'
    r')$',
    caseSensitive: false,
  );

  static final RegExp _inlineDateRe = RegExp(
    r'\b(?:'
    r'(\d{4})[-./](\d{1,2})[-./](\d{1,2})'
    '|'
    '(\\d{1,2})(?:st|nd|rd|th)?[\\s,./-]+($_monthPattern|\\d{1,2})[\\s,./-]+(\\d{2,4})'
    r')\b',
    caseSensitive: false,
  );

  static final RegExp _totalLineRe = RegExp(r'\btotal\b', caseSensitive: false);

  static final RegExp _amountRe =
      RegExp(r'(?:₹|rs\.?|inr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*$', caseSensitive: false);

  static final RegExp _anyAmountRe =
      RegExp(r'(?:₹|rs\.?|inr)?\s*\b([0-9,]+(?:\.[0-9]{1,2})?)\b', caseSensitive: false);

  static final RegExp _othersPrefixRe =
      RegExp(r'^others?\s*[-:]\s*([a-z0-9 &]{1,40})', caseSensitive: false);

  static DateTime? _parseDateMatch(RegExpMatch m, {bool hasOuterGroup = false}) {
    final offset = hasOuterGroup ? 1 : 0;
    int y, mo, d;
    if (m.group(1 + offset) != null) {
      y = int.parse(m.group(1 + offset)!);
      mo = int.parse(m.group(2 + offset)!);
      d = int.parse(m.group(3 + offset)!);
    } else {
      d = int.parse(m.group(4 + offset)!);
      final rawMo = m.group(5 + offset)!.toLowerCase();
      mo = _months[rawMo] ?? int.tryParse(rawMo) ?? 0;
      y = int.parse(m.group(6 + offset)!);
      if (y < 100) y += 2000;
    }
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  static String _capitalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return 'Other';
    return t[0].toUpperCase() + t.substring(1);
  }

  static String _categorize(String rawLabel) {
    final lower = rawLabel.trim().toLowerCase();
    final othersMatch = _othersPrefixRe.firstMatch(lower);
    if (othersMatch != null) {
      return _capitalize(othersMatch.group(1)!);
    }

    const food = [
      'lunch', 'dinner', 'breakfast', 'snacks', 'snack', 'tea', 'coffee',
      'food', 'biryani', 'swiggy', 'zomato', 'cafe', 'restaurant', 'meal', 'juice',
    ];
    const transport = [
      'uber', 'ola', 'rapido', 'auto', 'cab', 'bus', 'train', 'metro',
      'fuel', 'petrol', 'diesel', 'parking', 'toll', 'travel', 'flight',
    ];
    const groceries = [
      'grocery', 'groceries', 'milk', 'vegetables', 'veggies', 'fruits',
      'dmart', 'zepto', 'blinkit', 'bigbasket', 'instamart', 'rice',
    ];
    const bills = [
      'bill', 'bills', 'electricity', 'water', 'wifi', 'internet',
      'recharge', 'mobile', 'rent', 'gas', 'eb', 'broadband',
    ];
    const shopping = [
      'amazon', 'flipkart', 'myntra', 'shopping', 'clothes', 'shoes', 'dress',
    ];
    const health = [
      'doctor', 'medicine', 'pharmacy', 'hospital', 'medical', 'health', 'clinic',
    ];
    const entertainment = [
      'movie', 'netflix', 'spotify', 'game', 'entertainment', 'prime', 'hotstar',
    ];

    bool hasAny(List<String> keys) => keys.any((k) => lower.contains(k));

    if (hasAny(food)) return 'Food';
    if (hasAny(transport)) return 'Transport';
    if (hasAny(groceries)) return 'Groceries';
    if (hasAny(bills)) return 'Bills';
    if (hasAny(shopping)) return 'Shopping';
    if (hasAny(health)) return 'Health';
    if (hasAny(entertainment)) return 'Entertainment';

    return _capitalize(rawLabel.split(RegExp(r'[\s,]+')).first);
  }

  static List<ParsedBulkExpense> parse(String raw) {
    final results = <ParsedBulkExpense>[];
    DateTime currentDate = DateTime.now();
    bool hasItemsForDate = false;
    double? pendingTotalForDate;

    void flushPendingTotal() {
      if (!hasItemsForDate && pendingTotalForDate != null) {
        results.add(
          ParsedBulkExpense(
            date: currentDate,
            category: 'Other',
            amount: pendingTotalForDate!,
            note: 'Other Total',
          ),
        );
      }
      hasItemsForDate = false;
      pendingTotalForDate = null;
    }

    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final headerDateMatch = _dateHeaderRe.firstMatch(line);
      if (headerDateMatch != null) {
        final parsed = _parseDateMatch(headerDateMatch, hasOuterGroup: true);
        if (parsed != null) {
          flushPendingTotal();
          currentDate = parsed;
        }
        continue;
      }

      if (_totalLineRe.hasMatch(line)) {
        final totMatch = _anyAmountRe.firstMatch(line);
        if (totMatch != null) {
          final tot = double.tryParse((totMatch.group(1) ?? '').replaceAll(',', ''));
          if (tot != null && tot > 0 && tot <= 99999999.99) {
            pendingTotalForDate = tot;
          }
        }
        continue;
      }

      // Extract optional inline date (e.g. "others-soap, 23.11.26, 50")
      DateTime itemDate = currentDate;
      var work = line;
      final inlineMatch = _inlineDateRe.firstMatch(work);
      if (inlineMatch != null) {
        final parsed = _parseDateMatch(inlineMatch, hasOuterGroup: false);
        if (parsed != null) {
          itemDate = parsed;
          work = work.replaceRange(inlineMatch.start, inlineMatch.end, ' ').trim();
        }
      }

      final amtMatch = _amountRe.firstMatch(work) ?? _anyAmountRe.firstMatch(work);
      if (amtMatch == null) continue;
      final amount = double.tryParse((amtMatch.group(1) ?? '').replaceAll(',', ''));
      if (amount == null || amount <= 0 || amount > 99999999.99) continue;

      final labelPart = work
          .replaceRange(amtMatch.start, amtMatch.end, ' ')
          .replaceAll(RegExp(r'^[\s,=:-]+|[\s,=:-]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (labelPart.isEmpty) continue;

      final category = _categorize(labelPart);
      final note = _othersPrefixRe.hasMatch(labelPart.toLowerCase())
          ? category
          : labelPart;

      hasItemsForDate = true;
      results.add(
        ParsedBulkExpense(
          date: itemDate,
          category: category,
          amount: amount,
          note: note,
        ),
      );
    }

    flushPendingTotal();
    return results;
  }
}
