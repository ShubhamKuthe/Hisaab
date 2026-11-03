import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';

import '../data/hisaab_data.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../models/entry.dart';
import '../security/pin.dart';
import '../utils/format.dart' show localDigitSet;

/// Totals for a day (or any group of entries).
class TodaySummary {
  const TodaySummary({
    required this.moneyIn,
    required this.moneyOut,
    required this.udhaarGiven,
    this.sales = 0,
    this.paymentsReceived = 0,
    this.cashIn = 0,
    this.upiIn = 0,
    this.cashOut = 0,
    this.upiOut = 0,
    this.bills = 0,
    this.count = 0,
  });
  final int moneyIn;
  final int moneyOut;
  final int udhaarGiven;
  final int sales;
  final int paymentsReceived;
  final int cashIn;
  final int upiIn;
  final int cashOut;
  final int upiOut;
  final int bills;
  final int count;
  int get net => moneyIn - moneyOut;

  /// What should be in the cash drawer from these entries.
  int get cashInHand => cashIn - cashOut;

  static TodaySummary of(Iterable<Entry> entries) {
    var moneyIn = 0, moneyOut = 0, udhaar = 0, sales = 0, payments = 0;
    var cashIn = 0, upiIn = 0, cashOut = 0, upiOut = 0, bills = 0, count = 0;
    for (final e in entries) {
      count++;
      if (e.isBill) bills++;
      final upi = e.payMode == PayMode.upi;
      if (e.type.isMoneyIn) {
        moneyIn += e.amountPaise;
        if (e.type == EntryType.sale) {
          sales += e.amountPaise;
        } else {
          payments += e.amountPaise;
        }
        if (upi) {
          upiIn += e.amountPaise;
        } else {
          cashIn += e.amountPaise;
        }
      } else if (e.type == EntryType.expense) {
        moneyOut += e.amountPaise;
        if (upi) {
          upiOut += e.amountPaise;
        } else {
          cashOut += e.amountPaise;
        }
      } else {
        udhaar += e.amountPaise;
      }
    }
    return TodaySummary(
      moneyIn: moneyIn,
      moneyOut: moneyOut,
      udhaarGiven: udhaar,
      sales: sales,
      paymentsReceived: payments,
      cashIn: cashIn,
      upiIn: upiIn,
      cashOut: cashOut,
      upiOut: upiOut,
      bills: bills,
      count: count,
    );
  }
}

/// Money in and out on one day (for the report chart).
class DayTotal {
  const DayTotal(this.day, this.moneyIn, this.moneyOut);
  final DateTime day;
  final int moneyIn;
  final int moneyOut;
  int get net => moneyIn - moneyOut;
}

/// A report for a range of days.
class PeriodReport {
  const PeriodReport({
    required this.from,
    required this.to,
    required this.summary,
    required this.days,
    required this.topExpenses,
  });
  final DateTime from;

  /// Last day included.
  final DateTime to;
  final TodaySummary summary;

  /// Every day in the range, oldest first (days with nothing are zeros).
  final List<DayTotal> days;

  /// Biggest expenses grouped by who was paid / note. Key null = no name.
  final List<MapEntry<String?, int>> topExpenses;

  DayTotal? get bestDay {
    DayTotal? best;
    for (final d in days) {
      if (d.moneyIn > 0 && (best == null || d.moneyIn > best.moneyIn)) best = d;
    }
    return best;
  }

  int get activeDays => days.where((d) => d.moneyIn > 0 || d.moneyOut > 0).length;
}

class CustomerBalance {
  const CustomerBalance({
    required this.name,
    required this.duePaise,
    required this.lastActivity,
  });
  final String name;

  /// Positive: the customer owes the shop. Negative: paid in advance.
  final int duePaise;
  final DateTime lastActivity;
}

/// Someone the shop paid (staff, supplier) and how much in total.
class PaidToTotal {
  const PaidToTotal({required this.name, required this.totalPaise, required this.lastActivity});
  final String name;
  final int totalPaise;
  final DateTime lastActivity;
}

/// The whole app's state: settings and the shop's book.
class AppState extends ChangeNotifier {
  AppState(this._store, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final HisaabStore _store;
  final DateTime Function() _clock;

  HisaabData _data = HisaabData();
  bool _loaded = false;
  bool _saveFailed = false;
  int _idSeq = 0;
  Future<void> _pendingSave = Future<void>.value();

  bool get loaded => _loaded;
  bool get saveFailed => _saveFailed;
  AppLang? get lang => _data.lang;
  bool get devanagariDigits => _data.devanagariDigits;
  bool get simpleMode => _data.simpleMode;
  ThemeMode get themeMode => switch (_data.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  String? get shopName => _data.shopName;
  String? get shopPhone => _data.shopPhone;
  String? get shopUpi => _data.shopUpi;
  bool get autoBackup => _data.autoBackup;

  /// Cash or UPI, whichever was picked last time.
  PayMode get lastPayMode => _data.lastPayMode;

  /// The number the next bill will get.
  int get nextBillNo => _data.billCounter + 1;
  String? get backupDir => _data.backupDir;
  DateTime? get lastBackupAt => _data.lastBackupAt;

  /// Whole days since the last backup, or null if never backed up.
  int? daysSinceBackup() {
    final last = _data.lastBackupAt;
    if (last == null) return null;
    final now = _clock();
    final a = DateTime(last.year, last.month, last.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }
  S get s => S(_data.lang ?? AppLang.mr);

  /// Newest first.
  List<Entry> get entries => List.unmodifiable(_data.entries);

  Future<void> init() async {
    try {
      _data = await _store.load();
    } catch (e) {
      debugPrint('Hisaab: could not load data: $e');
      _data = HisaabData();
    }
    _data.entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _applyDigits();
    _loaded = true;
    notifyListeners();
  }

  /// Resolves when every change so far has been written to disk.
  Future<void> flush() => _pendingSave;

  void setLang(AppLang lang) {
    _data.lang = lang;
    _applyDigits();
    _changed();
  }

  /// Local digits follow the language: १२३ for Marathi, ১২৩ for Bengali...
  void _applyDigits() {
    final l = _data.lang ?? AppLang.mr;
    localDigitSet = l == AppLang.en ? '०१२३४५६७८९' : l.digits;
  }

  void setDevanagariDigits(bool value) {
    _data.devanagariDigits = value;
    _changed();
  }

  /// Cycles: follow Windows -> light -> dark -> follow Windows.
  void cycleTheme() {
    _data.theme = switch (_data.theme) {
      'system' => 'light',
      'light' => 'dark',
      _ => 'system',
    };
    _changed();
  }

  void setSimpleMode(bool value) {
    _data.simpleMode = value;
    _changed();
  }

  void setShopInfo({String? name, String? phone}) {
    _data.shopName = _clean(name);
    _data.shopPhone = _clean(phone);
    _changed();
  }

  /// UPI ID like "ramstore@okaxis". Returns false (and saves nothing) if it
  /// doesn't look like a UPI ID. Empty clears it.
  bool setShopUpi(String? upi) {
    final t = (upi ?? '').trim().replaceAll(' ', '');
    if (t.isNotEmpty && !isValidUpi(t)) return false;
    _data.shopUpi = t.isEmpty ? null : t;
    _changed();
    return true;
  }

  static bool isValidUpi(String v) => RegExp(r'^[A-Za-z0-9._-]{2,256}@[A-Za-z][A-Za-z0-9.-]{1,63}$').hasMatch(v.trim());

  void setAutoBackup(bool on) {
    _data.autoBackup = on;
    _changed();
  }

  /// True when the daily automatic backup should run now.
  bool autoBackupDue() {
    if (!_data.autoBackup || _data.backupDir == null || _data.entries.isEmpty) return false;
    final last = _data.lastBackupAt;
    return last == null || !_sameDay(last, _clock());
  }

  String? phoneFor(String customer) => _data.customerPhones[_key(customer)];

  void setCustomerPhone(String customer, String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      _data.customerPhones.remove(_key(customer));
    } else {
      _data.customerPhones[_key(customer)] = digits;
    }
    _changed();
  }

  /// Items used on earlier bills with their last price, most recent first.
  List<MapEntry<String, int>> knownItems() =>
      _data.itemPrices.entries.toList().reversed.toList();

  /// Saves a bill: one entry holding all its items. A paid bill is a sale;
  /// "pay later" makes it udhaar for the customer.
  Entry saveBill({
    required List<BillItem> items,
    String? customer,
    bool payLater = false,
    PayMode? mode,
  }) {
    final clean = [
      for (final i in items)
        if (i.name.trim().isNotEmpty && i.qty > 0 && i.pricePaise > 0)
          BillItem(name: i.name.trim(), qty: i.qty, pricePaise: i.pricePaise),
    ];
    if (clean.isEmpty) throw ArgumentError('A bill needs at least one item');
    final total = clean.fold<int>(0, (sum, i) => sum + i.totalPaise);
    final billNo = _data.billCounter + 1;
    final entry = addEntry(
      type: payLater ? EntryType.udhaarGiven : EntryType.sale,
      amountPaise: total,
      customer: customer,
      billNo: billNo,
      items: clean,
      mode: payLater ? null : mode,
    );
    _data.billCounter = billNo;
    for (final i in clean) {
      // Re-insert so the most recently used item moves to the end.
      _data.itemPrices.remove(i.name);
      _data.itemPrices[i.name] = i.pricePaise;
    }
    while (_data.itemPrices.length > 300) {
      _data.itemPrices.remove(_data.itemPrices.keys.first);
    }
    _changed();
    return entry;
  }

  Entry addEntry({
    required EntryType type,
    required int amountPaise,
    String? customer,
    String? note,
    int? billNo,
    List<BillItem> items = const [],
    PayMode? mode,
  }) {
    if (amountPaise <= 0) {
      throw ArgumentError.value(amountPaise, 'amountPaise', 'must be > 0');
    }
    final name = _clean(customer);
    if (type.needsCustomer && name == null) {
      throw ArgumentError('A customer is required for ${type.name}');
    }
    final now = _clock();
    final entry = Entry(
      id: '${now.microsecondsSinceEpoch}-${_idSeq++}',
      type: type,
      amountPaise: amountPaise,
      createdAt: now,
      customer: name,
      note: _clean(note),
      billNo: billNo,
      items: items,
      mode: type.hasPayMode ? (mode ?? PayMode.cash) : null,
    );
    if (mode != null && type.hasPayMode) _data.lastPayMode = mode;
    _data.entries.insert(0, entry);
    _changed();
    return entry;
  }

  /// Fixes a mistake: same entry (id and time stay), new amount / name / note / mode.
  void updateEntry(Entry updated) {
    if (updated.amountPaise <= 0) {
      throw ArgumentError.value(updated.amountPaise, 'amountPaise', 'must be > 0');
    }
    if (updated.type.needsCustomer && _clean(updated.customer) == null) {
      throw ArgumentError('A customer is required for ${updated.type.name}');
    }
    final i = _data.entries.indexWhere((e) => e.id == updated.id);
    if (i < 0) return;
    _data.entries[i] = Entry(
      id: updated.id,
      type: updated.type,
      amountPaise: updated.amountPaise,
      createdAt: updated.createdAt,
      customer: _clean(updated.customer),
      note: _clean(updated.note),
      billNo: updated.billNo,
      items: updated.items,
      mode: updated.type.hasPayMode ? updated.payMode : null,
    );
    _changed();
  }

  /// Undo for delete: puts the entry back where it was.
  void restoreEntry(Entry entry) {
    if (_data.entries.any((e) => e.id == entry.id)) return;
    _data.entries.add(entry);
    _data.entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _changed();
  }

  // ---------- PIN lock ----------

  bool _unlocked = false;
  int _failedTries = 0;
  DateTime? _lockedUntil;

  bool get hasPin => _data.pinHash != null && _data.pinSalt != null;
  bool get unlocked => _unlocked;

  /// First-time setup (or reset): saves the PIN and the recovery code.
  void setPin(String pin, String recoveryCode) {
    if (!PinCrypto.isValidPin(pin)) throw ArgumentError('PIN must be 4 digits');
    final salt = PinCrypto.newSalt();
    _data.pinSalt = salt;
    _data.pinHash = PinCrypto.hash(pin, salt);
    _data.recoveryHash = PinCrypto.hash('recovery:$recoveryCode', salt);
    _unlocked = true;
    _failedTries = 0;
    _lockedUntil = null;
    _changed();
  }

  /// Time left before another try is allowed, or null if not locked out.
  Duration? lockoutLeft() {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(_clock());
    return left.isNegative || left == Duration.zero ? null : left;
  }

  /// Checks the PIN. After 5 wrong tries, waits 30s, then 60s, 90s...
  bool unlock(String pin) {
    if (!hasPin) return true;
    final ok = checkPin(pin);
    if (ok) _unlocked = true;
    notifyListeners();
    return ok;
  }

  /// Checks the PIN without changing lock state (used by Change PIN).
  /// Wrong tries count towards the same 5-try lockout as unlocking.
  bool checkPin(String pin) {
    if (!hasPin) return true;
    if (lockoutLeft() != null) return false;
    final ok = PinCrypto.sameHash(PinCrypto.hash(pin, _data.pinSalt!), _data.pinHash!);
    if (ok) {
      _failedTries = 0;
      _lockedUntil = null;
    } else {
      _failedTries++;
      if (_failedTries >= 5) {
        _lockedUntil = _clock().add(Duration(seconds: 30 * (_failedTries - 4)));
      }
      notifyListeners();
    }
    return ok;
  }

  /// Forgot PIN: the recovery code from the notebook allows a new PIN.
  bool checkRecoveryCode(String code) {
    final salt = _data.pinSalt;
    final saved = _data.recoveryHash;
    if (salt == null || saved == null) return false;
    if (lockoutLeft() != null) return false;
    final ok = PinCrypto.sameHash(PinCrypto.hash('recovery:$code', salt), saved);
    if (!ok) {
      _failedTries++;
      if (_failedTries >= 5) {
        _lockedUntil = _clock().add(Duration(seconds: 30 * (_failedTries - 4)));
      }
      notifyListeners();
    }
    return ok;
  }

  void lock() {
    if (!hasPin) return;
    _unlocked = false;
    notifyListeners();
  }

  void setBackupDir(String? path) {
    _data.backupDir = path;
    _changed();
  }

  void markBackedUp() {
    _data.lastBackupAt = _clock();
    _changed();
  }

  /// Adds entries from a backup that are not already in the book
  /// (matched by id), so restoring twice never duplicates anything.
  /// Returns how many were added.
  int mergeEntries(Iterable<Entry> incoming) {
    final have = {for (final e in _data.entries) e.id};
    var added = 0;
    for (final e in incoming) {
      if (have.add(e.id)) {
        _data.entries.add(e);
        added++;
      }
    }
    if (added > 0) {
      _data.entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _changed();
    }
    return added;
  }

  void deleteEntry(String id) {
    _data.entries.removeWhere((e) => e.id == id);
    _changed();
  }

  // ---------- Questions the shopkeeper asks ----------

  List<Entry> todayEntries() {
    final now = _clock();
    return _data.entries.where((e) => _sameDay(e.createdAt, now)).toList();
  }

  TodaySummary today() => TodaySummary.of(todayEntries());

  DateTime get now => _clock();

  List<Entry> entriesOn(DateTime day) =>
      _data.entries.where((e) => _sameDay(e.createdAt, day)).toList();

  TodaySummary summaryOn(DateTime day) => TodaySummary.of(entriesOn(day));

  /// Report from [from] to [to] (both days included).
  PeriodReport report(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    final inRange = _data.entries.where((e) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
    final byDay = <DateTime, List<int>>{};
    final expenses = <String?, int>{};
    final shown = <String?, String?>{};
    for (final e in inRange) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      final t = byDay.putIfAbsent(d, () => [0, 0]);
      if (e.type.isMoneyIn) t[0] += e.amountPaise;
      if (e.type == EntryType.expense) {
        t[1] += e.amountPaise;
        final label = e.customer ?? e.note;
        final k = label == null ? null : _key(label);
        shown[k] = label;
        expenses[k] = (expenses[k] ?? 0) + e.amountPaise;
      }
    }
    final days = <DayTotal>[];
    for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      final t = byDay[d];
      days.add(DayTotal(d, t?[0] ?? 0, t?[1] ?? 0));
    }
    final top = [for (final k in expenses.keys) MapEntry(shown[k], expenses[k]!)]
      ..sort((a, b) => b.value.compareTo(a.value));
    return PeriodReport(
      from: start,
      to: end,
      summary: TodaySummary.of(inRange),
      days: days,
      topExpenses: top.take(6).toList(),
    );
  }

  /// All money that ever came in (sales + payments received) minus every
  /// expense. Udhaar given is goods on credit, so it is not counted here.
  int moneyWithMe() {
    var total = 0;
    for (final e in _data.entries) {
      if (e.type.isMoneyIn) {
        total += e.amountPaise;
      } else if (e.type == EntryType.expense) {
        total -= e.amountPaise;
      }
    }
    return total;
  }

  /// Every customer with what they owe, biggest due first.
  List<CustomerBalance> balances() {
    final due = <String, int>{};
    final names = <String, String>{};
    final last = <String, DateTime>{};
    // Oldest to newest, so the latest spelling of a name wins.
    for (final e in _data.entries.reversed) {
      final c = e.customer;
      // A name on an expense is staff or a supplier, never a customer.
      if (c == null || e.type == EntryType.expense) continue;
      final k = _key(c);
      names[k] = c;
      last[k] = e.createdAt;
      if (e.type == EntryType.udhaarGiven) {
        due[k] = (due[k] ?? 0) + e.amountPaise;
      } else if (e.type == EntryType.paymentReceived) {
        due[k] = (due[k] ?? 0) - e.amountPaise;
      } else {
        due[k] = due[k] ?? 0;
      }
    }
    final list = [
      for (final k in names.keys)
        CustomerBalance(name: names[k]!, duePaise: due[k] ?? 0, lastActivity: last[k]!),
    ];
    list.sort((a, b) {
      final byDue = b.duePaise.compareTo(a.duePaise);
      return byDue != 0 ? byDue : b.lastActivity.compareTo(a.lastActivity);
    });
    return list;
  }

  int totalDue() => balances()
      .where((b) => b.duePaise > 0)
      .fold(0, (sum, b) => sum + b.duePaise);

  /// Customer names, most recently used first (for quick-pick chips).
  List<String> recentCustomers() {
    final list = balances()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return [for (final b in list) b.name];
  }

  List<Entry> entriesFor(String customer) {
    final k = _key(customer);
    return _data.entries
        .where((e) =>
            e.type != EntryType.expense && e.customer != null && _key(e.customer!) == k)
        .toList();
  }

  /// Everyone you've paid on an expense, with the total paid, most recent first.
  List<PaidToTotal> paidToTotals() {
    final total = <String, int>{};
    final names = <String, String>{};
    final last = <String, DateTime>{};
    for (final e in _data.entries.reversed) {
      final c = e.customer;
      if (e.type != EntryType.expense || c == null) continue;
      final k = _key(c);
      names[k] = c;
      last[k] = e.createdAt;
      total[k] = (total[k] ?? 0) + e.amountPaise;
    }
    final list = [
      for (final k in names.keys)
        PaidToTotal(name: names[k]!, totalPaise: total[k]!, lastActivity: last[k]!),
    ]..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return list;
  }

  /// All expenses paid to / spent by one person, newest first.
  List<Entry> expensesFor(String name) {
    final k = _key(name);
    return _data.entries
        .where((e) => e.type == EntryType.expense && e.customer != null && _key(e.customer!) == k)
        .toList();
  }

  /// People named on expenses (staff, suppliers), most recent first.
  List<String> recentSpenders() {
    final seen = <String>{};
    final out = <String>[];
    for (final e in _data.entries) {
      final c = e.customer;
      if (e.type != EntryType.expense || c == null) continue;
      if (seen.add(_key(c))) out.add(c);
    }
    return out;
  }

  int dueFor(String customer) {
    final k = _key(customer);
    for (final b in balances()) {
      if (_key(b.name) == k) return b.duePaise;
    }
    return 0;
  }

  // ---------- internals ----------

  void _changed() {
    notifyListeners();
    final snapshot = _data.copy();
    // Saves run one after another, never at the same time.
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _store.save(snapshot);
        if (_saveFailed) {
          _saveFailed = false;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Hisaab: save failed: $e');
        _saveFailed = true;
        notifyListeners();
      }
    });
  }

  static String? _clean(String? s) {
    final t = s?.trim().replaceAll(RegExp(r'\s+'), ' ');
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _key(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
