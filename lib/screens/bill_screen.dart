import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app.dart';
import '../bills/receipt_output.dart';
import '../l10n/strings.dart';
import '../export/hisaab_export.dart' show showInFolder;
import '../models/entry.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../utils/platform_share.dart';
import '../widgets/voice_input.dart';
import 'add_entry_screen.dart' show PayModePicker;
import '../widgets/motion.dart';

/// Make a bill: items, quantity, price -> total. Save, then print it or make
/// a picture for WhatsApp. Kept deliberately simple.
class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _ItemRow {
  _ItemRow({String name = '', String price = ''})
      : name = TextEditingController(text: name),
        qty = TextEditingController(text: '1'),
        price = TextEditingController(text: price);
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController price;

  BillItem? toItem() {
    final q = parseQty(qty.text);
    final p = parsePricePaise(price.text);
    if (name.text.trim().isEmpty || q == null || p == null) return null;
    return BillItem(name: name.text.trim(), qty: q, pricePaise: p);
  }

  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

class _BillScreenState extends State<BillScreen> {
  final _rows = <_ItemRow>[_ItemRow()];
  final _customer = TextEditingController();
  late final TextEditingController _shopName;
  late final TextEditingController _shopPhone;
  late final TextEditingController _shopUpi;
  final _previewKey = GlobalKey();
  bool _payLater = false;
  PayMode? _mode;
  String? _upiError;
  bool _busy = false;
  String? _error;
  bool _initDone = false;
  late AppState _state;

  /// Shop details are typed once and remembered. Once saved they fold into a
  /// small line with an Edit button.
  bool _editingShop = false;
  Timer? _shopSave;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context);
    if (!_initDone) {
      _shopName = TextEditingController(text: _state.shopName ?? '');
      _shopPhone = TextEditingController(text: _state.shopPhone ?? '');
      _shopUpi = TextEditingController(text: _state.shopUpi ?? '');
      _mode = _state.lastPayMode;
      _editingShop = (_state.shopName ?? '').isEmpty;
      _initDone = true;
    }
  }

  /// Saves shop name/phone a moment after typing stops.
  void _shopChanged() {
    setState(() {});
    _shopSave?.cancel();
    _shopSave = Timer(const Duration(milliseconds: 700), _saveShopNow);
  }

  void _saveShopNow() {
    _shopSave?.cancel();
    _shopSave = null;
    final name = _shopName.text.trim();
    final phone = _shopPhone.text.trim();
    if (name != (_state.shopName ?? '') || phone != (_state.shopPhone ?? '')) {
      _state.setShopInfo(name: name, phone: phone);
    }
    _saveUpiNow();
  }

  /// Saves the UPI ID if it looks right; otherwise shows a small error.
  void _saveUpiNow() {
    final upi = _shopUpi.text.trim().replaceAll(' ', '');
    if (upi == (_state.shopUpi ?? '')) {
      if (_upiError != null && mounted) setState(() => _upiError = null);
      return;
    }
    final ok = _state.setShopUpi(upi);
    if (mounted) setState(() => _upiError = ok ? null : _state.s.badUpi);
  }

  /// What the receipt uses: only a UPI ID that looks valid.
  String get _upiForReceipt {
    final upi = _shopUpi.text.trim().replaceAll(' ', '');
    return AppState.isValidUpi(upi) ? upi : '';
  }

  @override
  void dispose() {
    if (_shopSave != null) {
      // Leaving mid-typing: save right after this screen closes.
      _shopSave!.cancel();
      final name = _shopName.text, phone = _shopPhone.text, upi = _shopUpi.text, state = _state;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (name.trim() != (state.shopName ?? '') || phone.trim() != (state.shopPhone ?? '')) {
          state.setShopInfo(name: name, phone: phone);
        }
        if (upi.trim() != (state.shopUpi ?? '')) state.setShopUpi(upi);
      });
    }
    for (final r in _rows) {
      r.dispose();
    }
    _customer.dispose();
    _shopName.dispose();
    _shopPhone.dispose();
    _shopUpi.dispose();
    super.dispose();
  }

  List<BillItem> get _items => [
        for (final r in _rows)
          if (r.toItem() case final item?) item,
      ];

  void _addRow({String name = '', String price = ''}) {
    setState(() => _rows.add(_ItemRow(name: name, price: price)));
  }

  void _useKnownItem(String name, int pricePaise) {
    setState(() {
      final empty = _rows.where((r) => r.name.text.trim().isEmpty).toList();
      if (empty.isNotEmpty) {
        empty.first.name.text = name;
        empty.first.price.text = paiseToInput(pricePaise);
      } else {
        _rows.add(_ItemRow(name: name, price: paiseToInput(pricePaise)));
      }
      _error = null;
    });
  }

  void _removeRow(int i) {
    setState(() {
      _rows.removeAt(i).dispose();
      if (_rows.isEmpty) _rows.add(_ItemRow());
    });
  }

  Future<void> _save({required bool print}) async {
    final state = AppScope.of(context);
    final s = state.s;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final items = _items;
    if (items.isEmpty) {
      setState(() => _error = s.needItems);
      return;
    }
    if (_payLater && _customer.text.trim().isEmpty) {
      setState(() => _error = s.needCustomer);
      return;
    }
    _saveShopNow();
    setState(() {
      _busy = true;
      _error = null;
    });

    // Picture first, while the preview still shows this bill's number.
    final img = await captureReceipt(_previewKey);
    final billNo = state.nextBillNo;
    state.saveBill(
      items: items,
      customer: _customer.text.trim().isEmpty ? null : _customer.text,
      payLater: _payLater,
      mode: _mode,
    );

    try {
      if (print) {
        await printReceipt(img, name: 'Bill $billNo');
        messenger.showSnackBar(SnackBar(
          backgroundColor: HisaabColors.moneyIn,
          content: Text('✓ ${s.billSaved}', style: const TextStyle(fontSize: 18)),
        ));
      } else {
        final file = await saveReceiptImage(img, billNo);
        if (isPhone) {
          await shareFile(file);
        } else {
          messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: HisaabColors.moneyIn,
          content: Text('✓ ${s.billSaved} · ${s.billImageSaved}\n${file.path}',
              style: const TextStyle(fontSize: 16)),
          action: SnackBarAction(
            label: s.openFolder,
            textColor: Colors.white,
            onPressed: () => showInFolder(file),
          ),
        ));
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: HisaabColors.moneyOut,
        content: Text('✓ ${s.billSaved} · $e', style: const TextStyle(fontSize: 16)),
      ));
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final deva = state.devanagariDigits;
    final items = _items;
    final total = items.fold<int>(0, (sum, i) => sum + i.totalPaise);
    final known = state.knownItems().take(12).toList();

    final preview = ReceiptPreview(
      boundaryKey: _previewKey,
      shopName: _shopName.text.trim(),
      shopPhone: _shopPhone.text.trim(),
      billNo: state.nextBillNo,
      date: DateTime.now(),
      customer: _customer.text.trim(),
      items: items,
      payLater: _payLater,
      upi: _upiForReceipt,
    );

    final upiField = TextField(
      controller: _shopUpi,
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        labelText: '${s.shopUpi} ${s.optional}',
        hintText: 'ramstore@okaxis',
        prefixIcon: const Icon(Icons.qr_code_2),
        errorText: _upiError,
      ),
      onChanged: (_) => _shopChanged(),
      onSubmitted: (_) {
        _saveShopNow();
        if (_shopName.text.trim().isNotEmpty && _upiError == null) setState(() => _editingShop = false);
      },
    );

    final shopRow = Row(children: [
      Expanded(
        flex: 3,
        child: TextField(
          controller: _shopName,
          autofocus: (_state.shopName ?? '').isEmpty,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(labelText: s.shopName, prefixIcon: const Icon(Icons.storefront)),
          onChanged: (_) => _shopChanged(),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: TextField(
          controller: _shopPhone,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(labelText: s.shopPhone, prefixIcon: const Icon(Icons.phone)),
          onChanged: (_) => _shopChanged(),
          onSubmitted: (_) {
            _saveShopNow();
            if (_shopName.text.trim().isNotEmpty) setState(() => _editingShop = false);
          },
        ),
      ),
      if ((_state.shopName ?? '').isNotEmpty)
        IconButton(
          tooltip: s.done,
          icon: const Icon(Icons.check_circle, color: HisaabColors.moneyIn, size: 30),
          onPressed: () {
            _saveShopNow();
            if (_upiError == null) setState(() => _editingShop = false);
          },
        ),
    ]);

    final shopFields = Column(key: const ValueKey('shop-edit'), children: [
      shopRow,
      const SizedBox(height: 10),
      upiField,
    ]);

    final shopSummary = Material(
      key: const ValueKey('shop-summary'),
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          const Icon(Icons.storefront, color: HisaabColors.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              [
                _shopName.text.trim(),
                if (_shopPhone.text.trim().isNotEmpty) '☎ ${_shopPhone.text.trim()}',
                if (_upiForReceipt.isNotEmpty) 'UPI $_upiForReceipt',
              ].join('   ·   '),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _editingShop = true),
            icon: const Icon(Icons.edit, size: 20),
            label: Text(s.edit, style: const TextStyle(fontSize: 16)),
          ),
        ]),
      ),
    );

    final editor = <Widget>[
      AnimatedSwitcher(
        duration: motion(context, 220),
        child: _editingShop ? shopFields : shopSummary,
      ),
      const SizedBox(height: 18),
      if (known.isNotEmpty) ...[
        Text(s.recentItems, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in known)
            ActionChip(
              label: Text('${k.key}  ${formatRupees(k.value, devanagari: deva)}',
                  style: const TextStyle(fontSize: 16)),
              onPressed: () => _useKnownItem(k.key, k.value),
            ),
        ]),
        const SizedBox(height: 16),
      ],
      for (var i = 0; i < _rows.length; i++) _itemRowView(i, s),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _addRow(),
          icon: const Icon(Icons.add_circle_outline, size: 26),
          label: Text(s.addItem, style: const TextStyle(fontSize: 18)),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _customer,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          labelText: _payLater ? s.customerName : '${s.customerName} ${s.optional}',
          prefixIcon: const Icon(Icons.person),
          suffixIcon: MicButton(
            controller: _customer,
            names: true,
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
        onChanged: (_) => setState(() => _error = null),
      ),
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _payLater,
        activeColor: HisaabColors.udhaar,
        onChanged: (v) => setState(() {
          _payLater = v;
          _error = null;
        }),
        title: Text(s.payLater, style: const TextStyle(fontSize: 18)),
      ),
      if (!_payLater) ...[
        PayModePicker(value: _mode ?? PayMode.cash, onChanged: (m) => setState(() => _mode = m)),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 8),
      Row(children: [
        Text('${s.total}: ', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        AnimatedMoney(
          paise: total,
          devanagari: deva,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: HisaabColors.bill),
        ),
      ]),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!,
            style: const TextStyle(fontSize: 18, color: HisaabColors.moneyOut, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 60,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: HisaabColors.bill),
              onPressed: _busy ? null : () => _save(print: true),
              icon: const Icon(Icons.print, size: 26),
              label: Text(s.savePrint, style: const TextStyle(fontSize: 19)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 60,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: HisaabColors.moneyIn),
              onPressed: _busy ? null : () => _save(print: false),
              icon: const Icon(Icons.image, size: 26),
              label: Text(s.saveImage, style: const TextStyle(fontSize: 19)),
            ),
          ),
        ),
      ]),
    ];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            const Icon(Icons.receipt, color: HisaabColors.bill),
            const SizedBox(width: 10),
            Text(s.makeBill, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          ]),
        ),
        body: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 1000) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: ListView(padding: const EdgeInsets.all(24), children: editor)),
              SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: preview,
                ),
              ),
            ]);
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            ...editor,
            const SizedBox(height: 24),
            Center(child: FittedBox(fit: BoxFit.scaleDown, child: preview)),
          ]);
        }),
      ),
    );
  }

  Widget _itemRowView(int i, S s) {
    final r = _rows[i];
    final item = r.toItem();
    final deva = AppScope.of(context).devanagariDigits;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: TextField(
            controller: r.name,
            autofocus: i == _rows.length - 1 && i > 0,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: '${s.item} ${toDigits('${i + 1}', deva)}',
              suffixIcon: MicButton(
                controller: r.name,
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: r.qty,
            style: const TextStyle(fontSize: 18),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(decimalInputPattern)],
            decoration: InputDecoration(labelText: s.qty),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: r.price,
            style: const TextStyle(fontSize: 18),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(decimalInputPattern)],
            decoration: InputDecoration(labelText: s.price),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _addRow(),
          ),
        ),
        SizedBox(
          width: 110,
          child: Text(
            item == null ? '' : formatRupees(item.totalPaise, devanagari: deva),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: '×',
          icon: const Icon(Icons.close),
          onPressed: () => _removeRow(i),
        ),
      ]),
    );
  }
}

/// The paper receipt. Always black on white, whatever the app theme,
/// because this is exactly what gets printed or sent as a picture.
class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({
    super.key,
    required this.boundaryKey,
    required this.shopName,
    required this.shopPhone,
    required this.billNo,
    required this.date,
    required this.customer,
    required this.items,
    required this.payLater,
    this.upi = '',
  });

  final GlobalKey boundaryKey;

  /// Shop's UPI ID: when set, a "scan to pay" QR is printed on the bill.
  final String upi;
  final String shopName;
  final String shopPhone;
  final int billNo;
  final DateTime date;
  final String customer;
  final List<BillItem> items;
  final bool payLater;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final deva = state.devanagariDigits;
    final total = items.fold<int>(0, (sum, i) => sum + i.totalPaise);
    const ink = Color(0xFF111111);
    const faint = Color(0xFF555555);
    const rule = Divider(color: Color(0xFF999999), thickness: 1, height: 18);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: 320,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: ink, fontSize: 15, height: 1.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(shopName.isEmpty ? s.shopName : shopName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                if (shopPhone.isNotEmpty)
                  Text('☎ ${toDigits(shopPhone, deva)}',
                      textAlign: TextAlign.center, style: const TextStyle(color: faint)),
                rule,
                Row(children: [
                  Expanded(child: Text(toDigits('${s.billNo} $billNo', deva))),
                  Text(toDigits(
                      '${formatDate(date)}  ${formatTime(date)}', deva)),
                ]),
                if (customer.isNotEmpty)
                  Text('${s.customers}: $customer', style: const TextStyle(fontWeight: FontWeight.w600)),
                rule,
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${formatQty(i.qty, devanagari: deva)} × ${formatRupees(i.pricePaise, devanagari: deva)}',
                              style: const TextStyle(color: faint, fontSize: 13)),
                        ]),
                      ),
                      Text(formatRupees(i.totalPaise, devanagari: deva),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('—', textAlign: TextAlign.center, style: TextStyle(color: faint)),
                  ),
                rule,
                Row(children: [
                  Expanded(
                    child: Text(s.total, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  Text(formatRupees(total, devanagari: deva),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
                if (payLater) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: ink, width: 1.5)),
                    child: Text(s.unpaid,
                        textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
                if (upi.isNotEmpty && total > 0) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: QrImageView(
                      data: upiPayLink(upi: upi, shopName: shopName, amountPaise: total, billNo: billNo),
                      version: QrVersions.auto,
                      size: 150,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(s.scanToPay, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('UPI: $upi', textAlign: TextAlign.center, style: const TextStyle(color: faint, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                Text(s.thankYou, textAlign: TextAlign.center, style: const TextStyle(color: faint)),
                const SizedBox(height: 2),
                const Text('Hisaab', textAlign: TextAlign.center, style: TextStyle(color: faint, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An old bill from the book: look at it, print it again, or make a picture.
class BillViewScreen extends StatefulWidget {
  const BillViewScreen({super.key, required this.entry});
  final Entry entry;

  @override
  State<BillViewScreen> createState() => _BillViewScreenState();
}

class _BillViewScreenState extends State<BillViewScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _out({required bool print}) async {
    final s = AppScope.of(context).s;
    final messenger = ScaffoldMessenger.of(context);
    final no = widget.entry.billNo ?? 0;
    setState(() => _busy = true);
    try {
      final img = await captureReceipt(_key);
      if (print) {
        await printReceipt(img, name: 'Bill $no');
      } else {
        final file = await saveReceiptImage(img, no);
        if (isPhone) {
          await shareFile(file);
        } else {
          messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('✓ ${s.billImageSaved}\n${file.path}', style: const TextStyle(fontSize: 16)),
          action: SnackBarAction(label: s.openFolder, onPressed: () => showInFolder(file)),
        ));
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: HisaabColors.moneyOut,
        content: Text('$e', style: const TextStyle(fontSize: 16)),
      ));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final e = widget.entry;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Scaffold(
        appBar: AppBar(title: Text(toDigits('${s.billNo} ${e.billNo ?? ''}', state.devanagariDigits))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(children: [
              FittedBox(fit: BoxFit.scaleDown, child: ReceiptPreview(
                boundaryKey: _key,
                shopName: state.shopName ?? '',
                shopPhone: state.shopPhone ?? '',
                billNo: e.billNo ?? 0,
                date: e.createdAt,
                customer: state.simpleMode ? '' : (e.customer ?? ''),
                items: e.items,
                payLater: e.type == EntryType.udhaarGiven,
                upi: state.shopUpi ?? '',
              )),
              const SizedBox(height: 24),
              Wrap(spacing: 12, runSpacing: 12, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: HisaabColors.bill, minimumSize: const Size(180, 56)),
                  onPressed: _busy ? null : () => _out(print: true),
                  icon: const Icon(Icons.print),
                  label: Text(s.print, style: const TextStyle(fontSize: 19)),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: HisaabColors.moneyIn, minimumSize: const Size(180, 56)),
                  onPressed: _busy ? null : () => _out(print: false),
                  icon: const Icon(Icons.image),
                  label: Text(s.image, style: const TextStyle(fontSize: 19)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// UPI "pay" link any UPI app understands (PhonePe, GPay, Paytm, BHIM).
String upiPayLink({required String upi, required String shopName, required int amountPaise, int? billNo}) {
  final amount = (amountPaise / 100).toStringAsFixed(2);
  final name = Uri.encodeComponent(shopName.isEmpty ? 'Shop' : shopName);
  final note = billNo == null ? '' : '&tn=${Uri.encodeComponent('Bill $billNo')}';
  return 'upi://pay?pa=$upi&pn=$name&am=$amount&cu=INR$note';
}
