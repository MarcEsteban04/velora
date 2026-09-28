import '../../accounts/domain/account.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';

/// A transaction understood from a chat message, waiting to be confirmed.
class ParsedTransaction {
  const ParsedTransaction({
    required this.kind,
    required this.amountMinor,
    required this.accountId,
    required this.occurredAt,
    this.accountGuessed = false,
    this.toAccountId,
    this.categoryId,
    this.note,
  });

  final TransactionKind kind;
  final int amountMinor;
  final String accountId;

  /// True when no account was named and the usual one was assumed.
  final bool accountGuessed;
  final String? toAccountId;
  final String? categoryId;
  final String? note;
  final DateTime occurredAt;

  TransactionDraft toDraft() => TransactionDraft(
    kind: kind,
    amountMinor: amountMinor,
    accountId: accountId,
    toAccountId: kind == TransactionKind.transfer ? toAccountId : null,
    categoryId: kind == TransactionKind.transfer ? null : categoryId,
    note: note,
    occurredAt: occurredAt,
  );
}

/// Understands everyday money messages without the AI: "spent 250 on lunch
/// from cash", "grab 180 kahapon", "got 25k salary", "moved 1000 from bpi
/// to gcash". Returns null for questions or anything without an amount.
class TransactionParser {
  TransactionParser({
    required this.accounts,
    required this.categories,
    required this.now,
    this.defaultAccountId,
  });

  final List<Account> accounts;
  final List<Category> categories;
  final DateTime now;

  /// Used when no account is named: the most recently used one.
  final String? defaultAccountId;

  static final _question = RegExp(
    r'\?|^(how|what|when|where|why|which|who|can|could|should|is|are|do|does|did|will|magkano|ilan|ano|saan|bakit|paano|pwede)\b',
  );

  static final _amount = RegExp(
    r'(?<![\w.])(?:₱|php\s?|p(?=\d))?(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?\s*(k|thousand)?(?![\w/])',
  );

  static const _incomeWords = {
    'got',
    'get',
    'received',
    'receive',
    'earned',
    'earn',
    'salary',
    'sahod',
    'sweldo',
    'suweldo',
    'income',
    'kita',
    'bonus',
    'allowance',
    'refund',
    'refunded',
    'cashback',
    'sold',
    'collected',
    'paid me',
    'binayaran ako',
  };

  static const _transferWords = {
    'transfer',
    'transferred',
    'moved',
    'move',
    'sent',
    'send',
    'lipat',
    'nilipat',
    'withdrew',
    'withdraw',
    'cash out',
    'cashout',
    'cash in',
    'cashin',
    'top up',
    'topup',
    'topped up',
  };

  static const _spendWords = {
    'spent',
    'spend',
    'paid',
    'pay',
    'bought',
    'buy',
    'purchase',
    'purchased',
    'gastos',
    'gumastos',
    'bayad',
    'binayad',
    'binili',
    'bili',
    'cost',
    'expense',
    'charged',
  };

  /// Everyday words, English and Filipino, to category icon keys.
  static const _keywords = <String, String>{
    // Food
    'lunch': 'food', 'dinner': 'food', 'breakfast': 'food', 'brunch': 'food',
    'snack': 'food', 'snacks': 'food', 'merienda': 'food', 'food': 'food',
    'eat': 'food', 'ate': 'food', 'kain': 'food', 'ulam': 'food',
    'jollibee': 'food', 'mcdo': 'food', 'mcdonalds': 'food', 'kfc': 'food',
    'chowking': 'food', 'mang inasal': 'food', 'pizza': 'food',
    'burger': 'food', 'milk tea': 'food', 'milktea': 'food',
    'samgyup': 'food', 'grabfood': 'food', 'foodpanda': 'food',
    'restaurant': 'food', 'coffee': 'food', 'starbucks': 'food',
    'kape': 'food', 'bread': 'food', 'tinapay': 'food',
    // Transport
    'grab': 'transport', 'taxi': 'transport', 'jeep': 'transport',
    'jeepney': 'transport', 'tricycle': 'transport', 'trike': 'transport',
    'bus': 'transport', 'mrt': 'transport', 'lrt': 'transport',
    'train': 'transport', 'angkas': 'transport', 'joyride': 'transport',
    'move it': 'transport', 'fare': 'transport', 'pamasahe': 'transport',
    'gas': 'transport', 'gasoline': 'transport', 'fuel': 'transport',
    'diesel': 'transport', 'parking': 'transport', 'toll': 'transport',
    'uber': 'transport', 'commute': 'transport',
    // Groceries
    'grocery': 'groceries', 'groceries': 'groceries',
    'supermarket': 'groceries', 'puregold': 'groceries',
    'savemore': 'groceries', 'palengke': 'groceries', 'market': 'groceries',
    // Bills
    'bill': 'bills', 'bills': 'bills', 'rent': 'bills', 'upa': 'bills',
    'meralco': 'bills', 'electric': 'bills', 'electricity': 'bills',
    'kuryente': 'bills', 'water': 'bills', 'tubig': 'bills',
    'maynilad': 'bills', 'insurance': 'bills',
    // Phone and internet
    'load': 'phone', 'data': 'phone', 'internet': 'phone', 'wifi': 'phone',
    'globe': 'phone', 'smart': 'phone', 'dito': 'phone', 'pldt': 'phone',
    'converge': 'phone', 'postpaid': 'phone',
    // Shopping
    'shopee': 'shopping', 'lazada': 'shopping', 'clothes': 'shopping',
    'shoes': 'shopping', 'shirt': 'shopping', 'damit': 'shopping',
    'mall': 'shopping', 'uniqlo': 'shopping', 'shein': 'shopping',
    // Fun
    'movie': 'fun', 'movies': 'fun', 'cinema': 'fun', 'netflix': 'fun',
    'spotify': 'fun', 'game': 'fun', 'games': 'fun', 'steam': 'fun',
    'concert': 'fun', 'bar': 'fun', 'drinks': 'fun', 'inuman': 'fun',
    // Health
    'medicine': 'health', 'gamot': 'health', 'doctor': 'health',
    'dentist': 'health', 'hospital': 'health', 'pharmacy': 'health',
    'mercury': 'health', 'vitamins': 'health', 'checkup': 'health',
    'gym': 'health',
    // Home
    'furniture': 'home', 'appliance': 'home', 'repair': 'home',
    'laundry': 'home', 'cleaning': 'home',
    // Income
    'salary': 'salary', 'sahod': 'salary', 'sweldo': 'salary',
    'suweldo': 'salary', 'payroll': 'salary', 'paycheck': 'salary',
    'freelance': 'freelance', 'client': 'freelance', 'project': 'freelance',
    'commission': 'freelance', 'gig': 'freelance',
    'gift': 'gift', 'regalo': 'gift', 'ampao': 'gift', 'angpao': 'gift',
    'refund': 'refund', 'cashback': 'refund', 'reimbursement': 'refund',
    'interest': 'interest',
  };

  /// Filler to leave out of the note.
  static const _filler = {
    'on',
    'for',
    'from',
    'to',
    'into',
    'using',
    'via',
    'with',
    'at',
    'the',
    'a',
    'an',
    'my',
    'i',
    'me',
    'just',
    'sa',
    'ng',
    'na',
    'para',
    'gamit',
    'ko',
    'yung',
    'ang',
    'pesos',
    'peso',
    'php',
    'today',
    'yesterday',
    'kahapon',
    'kanina',
    'ngayon',
    'last',
    'night',
    'this',
    'morning',
    'and',
    'of',
    'worth',
    'in',
    'account',
    'wallet',
    'cash',
    ..._spendWords,
    ..._incomeWords,
    ..._transferWords,
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  };

  ParsedTransaction? parse(String message) {
    final text = message.trim().toLowerCase();
    if (text.isEmpty || _question.hasMatch(text)) return null;

    final amountMatch = _amount.firstMatch(text);
    if (amountMatch == null) return null;
    final amountMinor = _amountMinor(amountMatch);
    if (amountMinor <= 0) return null;

    bool has(Set<String> words) => words.any((w) => _hasWord(text, w));
    final found = _accountsIn(text);
    final isTransfer =
        has(_transferWords) &&
        (found.length >= 2 || RegExp(r'\b(to|into|sa)\b').hasMatch(text));
    final kind = isTransfer
        ? TransactionKind.transfer
        : has(_incomeWords)
        ? TransactionKind.income
        : TransactionKind.expense;
    final category = kind == TransactionKind.transfer
        ? null
        : _categoryIn(text, kind);

    // Without a spending word, only a named category or account says this
    // is a transaction and not just a number.
    if (kind == TransactionKind.expense &&
        !has(_spendWords) &&
        category == null &&
        found.isEmpty) {
      return null;
    }

    String? from;
    String? to;
    if (kind == TransactionKind.transfer) {
      from =
          _accountAfter(text, const ['from', 'galing sa']) ??
          (found.isNotEmpty ? found.first.id : null);
      to =
          _accountAfter(text, const ['to', 'into', 'sa']) ??
          (found.length > 1 ? found[1].id : null);
      if (from == to) to = null;
      if (from == null || to == null) return null;
    } else {
      from =
          _accountAfter(text, const [
            'from',
            'using',
            'via',
            'with',
            'gamit',
          ]) ??
          (found.isNotEmpty ? found.first.id : null);
    }
    final guessed = from == null;
    from ??= defaultAccountId ?? accounts.firstOrNull?.id;
    if (from == null) return null;

    return ParsedTransaction(
      kind: kind,
      amountMinor: amountMinor,
      accountId: from,
      accountGuessed: guessed,
      toAccountId: to,
      categoryId:
          category?.id ??
          (kind == TransactionKind.transfer ? null : _other(kind)),
      note: _note(text, amountMatch, category),
      occurredAt: _when(text),
    );
  }

  int _amountMinor(RegExpMatch m) {
    final whole = int.parse(m.group(1)!.replaceAll(',', ''));
    final cents = m.group(2) == null
        ? 0
        : int.parse(m.group(2)!.padRight(2, '0'));
    final k = m.group(3) != null;
    // "1.5k" is 1,500.
    if (k) return ((whole + cents / 100) * 1000 * 100).round();
    return whole * 100 + cents;
  }

  static bool _hasWord(String text, String word) =>
      RegExp('(^|[^a-z])${RegExp.escape(word)}(\$|[^a-z])').hasMatch(text);

  /// Names to match an account by: its own, and a short form ("BPI Savings"
  /// also matches "bpi").
  Iterable<(String, Account)> _accountNames() sync* {
    for (final a in accounts) {
      final name = a.name.toLowerCase().trim();
      yield (name, a);
      final first = name.split(RegExp(r'\s+')).first;
      if (first.length >= 3 && first != name) yield (first, a);
      if (a.institutionId case final i?) yield (i, a);
    }
  }

  /// Accounts named in the text, in the order they appear.
  List<Account> _accountsIn(String text) {
    final hits = <(int, Account)>[];
    final seen = <String>{};
    final names = _accountNames().toList()
      ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    for (final (name, a) in names) {
      if (seen.contains(a.id)) continue;
      final m = RegExp('(^|[^a-z])${RegExp.escape(name)}(\$|[^a-z])')
          .firstMatch(text);
      if (m != null) {
        hits.add((m.start, a));
        seen.add(a.id);
      }
    }
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, a) in hits) a];
  }

  /// The account named right after one of [words]: "from cash",
  /// "to my gcash", "gamit bpi".
  String? _accountAfter(String text, List<String> words) {
    final names = _accountNames().toList()
      ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    for (final w in words) {
      final pattern = RegExp(
        '(^|[^a-z])${RegExp.escape(w)}\\s+(my\\s+|the\\s+|ang\\s+)?',
      );
      for (final m in pattern.allMatches(text)) {
        final rest = text.substring(m.end);
        for (final (name, a) in names) {
          if (!rest.startsWith(name)) continue;
          final end = name.length;
          if (end == rest.length || !RegExp('[a-z]').hasMatch(rest[end])) {
            return a.id;
          }
        }
      }
    }
    return null;
  }

  Category? _categoryIn(String text, TransactionKind kind) {
    final options = categories.where((c) => c.kind == kind && !c.hidden);
    // A category named outright wins.
    final byName = options.toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final c in byName) {
      if (_hasWord(text, c.name.toLowerCase())) return c;
    }
    final keys = _keywords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (!_hasWord(text, k)) continue;
      final icon = _keywords[k]!;
      final hit = options.where((c) => c.icon == icon).firstOrNull;
      if (hit != null) return hit;
    }
    return null;
  }

  String? _other(TransactionKind kind) => categories
      .where((c) => c.kind == kind && !c.hidden && c.icon == 'other')
      .firstOrNull
      ?.id;

  String? _note(String text, RegExpMatch amount, Category? category) {
    var rest = text.replaceRange(amount.start, amount.end, ' ');
    for (final (name, _) in _accountNames()) {
      rest = rest.replaceAll(
        RegExp('(^|[^a-z])${RegExp.escape(name)}(?=\$|[^a-z])'),
        ' ',
      );
    }
    final words = rest
        .split(RegExp(r'[^a-z0-9ñ&\-]+'))
        .where((w) => w.length >= 2 && !_filler.contains(w))
        .toList();
    if (words.isEmpty) return null;
    var note = words.join(' ');
    if (category != null && note == category.name.toLowerCase()) return null;
    if (note.length > 40) note = note.substring(0, 40).trim();
    return note[0].toUpperCase() + note.substring(1);
  }

  DateTime _when(String text) {
    final today = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    DateTime daysAgo(int n, {int? hour}) => DateTime(
      now.year,
      now.month,
      now.day - n,
      hour ?? now.hour,
      hour == null ? now.minute : 0,
    );
    if (_hasWord(text, 'last night')) return daysAgo(1, hour: 20);
    if (_hasWord(text, 'yesterday') || _hasWord(text, 'kahapon')) {
      return daysAgo(1);
    }
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    for (final (i, d) in days.indexed) {
      // The most recent such day: today if it's today.
      if (_hasWord(text, d)) return daysAgo((now.weekday - (i + 1)) % 7);
    }
    return today;
  }
}
