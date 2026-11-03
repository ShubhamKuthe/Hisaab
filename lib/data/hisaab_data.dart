import '../l10n/strings.dart';
import '../models/entry.dart';

/// Everything Hisaab saves: settings plus the book of entries.
class HisaabData {
  HisaabData({
    this.lang,
    this.devanagariDigits = false,
    this.simpleMode = true,
    this.theme = 'system',
    this.backupDir,
    this.lastBackupAt,
    this.pinSalt,
    this.pinHash,
    this.recoveryHash,
    this.shopName,
    this.shopPhone,
    this.shopUpi,
    this.billCounter = 0,
    this.autoBackup = true,
    this.lastPayMode = PayMode.cash,
    Map<String, String>? customerPhones,
    Map<String, int>? itemPrices,
    List<Entry>? entries,
  })  : customerPhones = customerPhones ?? {},
        itemPrices = itemPrices ?? {},
        entries = entries ?? [];

  AppLang? lang;
  bool devanagariDigits;

  /// Simple mode (default): only sales and expenses, no names or udhaar.
  bool simpleMode;

  /// 'system', 'light' or 'dark'.
  String theme;

  /// Folder chosen for backups (pen drive / Google Drive folder).
  String? backupDir;
  DateTime? lastBackupAt;

  /// PIN lock: salted hashes only, never the PIN itself.
  String? pinSalt;
  String? pinHash;
  String? recoveryHash;

  /// Printed at the top of bills.
  String? shopName;
  String? shopPhone;

  /// Shop's UPI ID (e.g. ramstore@okaxis): a "scan to pay" QR goes on bills.
  String? shopUpi;
  int billCounter;

  /// Back up by itself once a day into [backupDir].
  bool autoBackup;

  /// Cash/UPI choice used last time, so the next entry starts with it.
  PayMode lastPayMode;

  /// Customer phone numbers for WhatsApp reminders, by lower-case name.
  final Map<String, String> customerPhones;

  /// Last price used for each item name, most recently used last.
  final Map<String, int> itemPrices;
  final List<Entry> entries;

  HisaabData copy() => HisaabData(
        lang: lang,
        devanagariDigits: devanagariDigits,
        simpleMode: simpleMode,
        theme: theme,
        backupDir: backupDir,
        lastBackupAt: lastBackupAt,
        pinSalt: pinSalt,
        pinHash: pinHash,
        recoveryHash: recoveryHash,
        shopName: shopName,
        shopPhone: shopPhone,
        shopUpi: shopUpi,
        billCounter: billCounter,
        autoBackup: autoBackup,
        lastPayMode: lastPayMode,
        customerPhones: Map.of(customerPhones),
        itemPrices: Map.of(itemPrices),
        entries: List.of(entries),
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'lang': lang?.name,
        'devanagariDigits': devanagariDigits,
        'simpleMode': simpleMode,
        'theme': theme,
        'backupDir': backupDir,
        'lastBackupAt': lastBackupAt?.toIso8601String(),
        'pinSalt': pinSalt,
        'pinHash': pinHash,
        'recoveryHash': recoveryHash,
        'shopName': shopName,
        'shopPhone': shopPhone,
        'shopUpi': shopUpi,
        'billCounter': billCounter,
        'autoBackup': autoBackup,
        'lastPayMode': lastPayMode.name,
        'customerPhones': customerPhones,
        'itemPrices': itemPrices,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory HisaabData.fromJson(Object? json) {
    if (json is! Map) return HisaabData();
    AppLang? lang;
    final l = json['lang'];
    for (final v in AppLang.values) {
      if (v.name == l) lang = v;
    }
    final list = <Entry>[];
    final raw = json['entries'];
    if (raw is List) {
      for (final r in raw) {
        final e = Entry.tryFromJson(r);
        if (e != null) list.add(e);
      }
    }
    final prices = <String, int>{};
    final rawPrices = json['itemPrices'];
    if (rawPrices is Map) {
      rawPrices.forEach((k, v) {
        if (k is String && v is num) prices[k] = v.toInt();
      });
    }
    final phones = <String, String>{};
    final rawPhones = json['customerPhones'];
    if (rawPhones is Map) {
      rawPhones.forEach((k, v) {
        if (k is String && v is String && v.isNotEmpty) phones[k] = v;
      });
    }
    final last = json['lastBackupAt'];
    final counter = json['billCounter'];
    return HisaabData(
      lang: lang,
      devanagariDigits: json['devanagariDigits'] == true,
      simpleMode: json['simpleMode'] != false, // missing = simple
      theme: const ['light', 'dark'].contains(json['theme']) ? json['theme'] as String : 'system',
      backupDir: _str(json['backupDir']),
      lastBackupAt: last is String ? DateTime.tryParse(last) : null,
      pinSalt: _str(json['pinSalt']),
      pinHash: _str(json['pinHash']),
      recoveryHash: _str(json['recoveryHash']),
      shopName: _str(json['shopName']),
      shopPhone: _str(json['shopPhone']),
      shopUpi: _str(json['shopUpi']),
      billCounter: counter is num ? counter.toInt() : 0,
      autoBackup: json['autoBackup'] != false, // missing = on
      lastPayMode: json['lastPayMode'] == 'upi' ? PayMode.upi : PayMode.cash,
      customerPhones: phones,
      itemPrices: prices,
      entries: list,
    );
  }

  static String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
}
