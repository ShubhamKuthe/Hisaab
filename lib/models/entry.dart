/// The four kinds of entry a shopkeeper makes.
enum EntryType { sale, expense, udhaarGiven, paymentReceived }

extension EntryTypeX on EntryType {
  /// Money that came into the shop (cash or UPI).
  bool get isMoneyIn =>
      this == EntryType.sale || this == EntryType.paymentReceived;

  /// Udhaar and payments always belong to a customer.
  bool get needsCustomer =>
      this == EntryType.udhaarGiven || this == EntryType.paymentReceived;
}

/// How money was paid: notes and coins, or UPI (PhonePe, GPay, Paytm...).
enum PayMode { cash, upi }

extension EntryTypeMode on EntryType {
  /// Sales, payments and expenses can be cash or UPI. Udhaar is goods on credit.
  bool get hasPayMode => this != EntryType.udhaarGiven;
}

/// One line on a bill: "Sugar  2 × ₹45 = ₹90". Quantity can be a fraction
/// (0.5 kg). Prices in paise.
class BillItem {
  const BillItem({required this.name, required this.qty, required this.pricePaise});

  final String name;
  final double qty;
  final int pricePaise;

  int get totalPaise => (qty * pricePaise).round();

  Map<String, dynamic> toJson() => {'n': name, 'q': qty, 'p': pricePaise};

  static BillItem? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final n = json['n'], q = json['q'], p = json['p'];
    if (n is! String || q is! num || p is! num) return null;
    return BillItem(name: n, qty: q.toDouble(), pricePaise: p.toInt());
  }
}

/// One line in the shop's book. Amounts are stored in paise to avoid
/// rounding errors. Entries made from a bill also keep the bill's items.
class Entry {
  const Entry({
    required this.id,
    required this.type,
    required this.amountPaise,
    required this.createdAt,
    this.customer,
    this.note,
    this.billNo,
    this.items = const [],
    this.mode,
  });

  final String id;
  final EntryType type;
  final int amountPaise;
  final DateTime createdAt;
  final String? customer;
  final String? note;
  final int? billNo;
  final List<BillItem> items;

  /// Cash or UPI. Old entries saved before this existed count as cash.
  final PayMode? mode;

  PayMode get payMode => mode ?? PayMode.cash;

  bool get isBill => billNo != null && items.isNotEmpty;

  /// Same entry (same id and time) with some fields changed. Pass an empty
  /// string to clear the customer or note.
  Entry copyWith({int? amountPaise, String? customer, String? note, PayMode? mode, EntryType? type}) => Entry(
        id: id,
        type: type ?? this.type,
        amountPaise: amountPaise ?? this.amountPaise,
        createdAt: createdAt,
        customer: customer == null ? this.customer : (customer.isEmpty ? null : customer),
        note: note == null ? this.note : (note.isEmpty ? null : note),
        billNo: billNo,
        items: items,
        mode: mode ?? this.mode,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amountPaise,
        'at': createdAt.toIso8601String(),
        if (customer != null) 'customer': customer,
        if (note != null) 'note': note,
        if (billNo != null) 'billNo': billNo,
        if (items.isNotEmpty) 'items': items.map((i) => i.toJson()).toList(),
        if (mode != null) 'mode': mode!.name,
      };

  /// Returns null for a damaged entry instead of throwing, so one bad
  /// line can never wipe out the rest of the book.
  static Entry? tryFromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final customer = json['customer'];
      final note = json['note'];
      final billNo = json['billNo'];
      final rawItems = json['items'];
      final rawMode = json['mode'];
      final items = <BillItem>[];
      if (rawItems is List) {
        for (final r in rawItems) {
          final item = BillItem.tryFromJson(r);
          if (item != null) items.add(item);
        }
      }
      return Entry(
        id: json['id'] as String,
        type: EntryType.values.byName(json['type'] as String),
        amountPaise: (json['amount'] as num).toInt(),
        createdAt: DateTime.parse(json['at'] as String),
        customer: customer is String ? customer : null,
        note: note is String ? note : null,
        billNo: billNo is num ? billNo.toInt() : null,
        items: items,
        mode: rawMode == 'upi' ? PayMode.upi : (rawMode == 'cash' ? PayMode.cash : null),
      );
    } catch (_) {
      return null;
    }
  }
}
