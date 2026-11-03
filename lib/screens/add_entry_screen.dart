import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models/entry.dart';
import '../utils/format.dart';
import '../widgets/common.dart' show deleteWithUndo;
import '../widgets/voice_input.dart';

/// Add a sale, expense, udhaar or payment - or fix one ([editing]).
/// Built for speed at the counter: type the amount, press Enter.
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({
    super.key,
    required this.type,
    this.customer,
    this.initialAmount,
    this.initialNote,
    this.editing,
  });
  final EntryType type;
  final String? customer;

  /// Pre-filled amount, e.g. from the home-screen calculator or voice.
  final String? initialAmount;
  final String? initialNote;

  /// When set, this screen edits that entry instead of adding a new one.
  final Entry? editing;

  /// Opens the edit screen for [e].
  static Future<void> edit(BuildContext context, Entry e) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AddEntryScreen(type: e.type, editing: e)),
      );

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  late final _amount = TextEditingController(
      text: widget.editing != null ? paiseToInput(widget.editing!.amountPaise) : (widget.initialAmount ?? ''));
  late final TextEditingController _customer =
      TextEditingController(text: widget.editing?.customer ?? widget.customer ?? '');
  late final _note = TextEditingController(text: widget.editing?.note ?? widget.initialNote ?? '');
  final _amountFocus = FocusNode();
  String? _error;
  PayMode? _mode;

  bool get _isEdit => widget.editing != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mode ??= widget.editing?.payMode ?? AppScope.of(context).lastPayMode;
  }

  @override
  void dispose() {
    _amount.dispose();
    _customer.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _press(String key) {
    var text = _amount.text;
    if (key == 'back') {
      if (text.isNotEmpty) text = text.substring(0, text.length - 1);
    } else if (text.length + key.length <= 9) {
      if (text.isEmpty && key.startsWith('0')) return; // no leading zeros
      text += key;
    }
    setState(() {
      _amount.text = text;
      _amount.selection = TextSelection.collapsed(offset: text.length);
      _error = null;
    });
  }

  void _save() {
    final state = AppScope.of(context);
    final s = state.s;
    final paise = parseRupeesToPaise(_amount.text);
    if (paise == null) {
      setState(() => _error = s.enterAmount);
      _amountFocus.requestFocus();
      return;
    }
    if (widget.type.needsCustomer && _customer.text.trim().isEmpty) {
      setState(() => _error = s.needCustomer);
      return;
    }
    final showCustomer = widget.type.needsCustomer || !state.simpleMode;
    final mode = widget.type.hasPayMode ? _mode : null;
    if (_isEdit) {
      state.updateEntry(widget.editing!.copyWith(
        amountPaise: paise,
        customer: showCustomer ? _customer.text.trim() : null,
        note: _note.text.trim(),
        mode: mode,
      ));
    } else {
      state.addEntry(
        type: widget.type,
        amountPaise: paise,
        customer: showCustomer ? _customer.text : null,
        note: _note.text,
        mode: mode,
      );
    }
    final color = HisaabColors.forType(widget.type);
    final how = mode == null ? '' : ' · ${mode == PayMode.upi ? s.upi : s.cash}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color,
      content: Text(
        '✓ ${_isEdit ? s.updated : s.saved}: ${s.typeLabel(widget.type)} '
        '${formatRupees(paise, devanagari: state.devanagariDigits)}$how',
        style: const TextStyle(fontSize: 18),
      ),
    ));
    Navigator.of(context).pop();
  }

  void _delete() {
    final nav = Navigator.of(context);
    deleteWithUndo(context, AppScope.of(context), widget.editing!);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final color = HisaabColors.forType(widget.type);
    final showCustomer = widget.type.needsCustomer || !state.simpleMode;
    final isExpense = widget.type == EntryType.expense;
    final query = _customer.text.trim().toLowerCase();
    // Expenses suggest staff/suppliers; everything else suggests customers.
    final suggestions = (isExpense ? state.recentSpenders() : state.recentCustomers())
        .where((n) => query.isEmpty || n.toLowerCase().contains(query))
        .where((n) => n.toLowerCase() != query)
        .take(8)
        .toList();

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          title: Row(children: [
            Icon(HisaabColors.iconFor(widget.type)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(_isEdit ? '${s.editEntry} · ${s.typeLabel(widget.type)}' : s.typeLabel(widget.type),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
          ]),
          actions: [
            if (_isEdit)
              IconButton(
                tooltip: s.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextField(
                  controller: _amount,
                  focusNode: _amountFocus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(digitInputPattern),
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: color),
                  decoration: InputDecoration(
                    labelText: s.amount,
                    labelStyle: const TextStyle(fontSize: 20),
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: color),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 12),
                _Numpad(onKey: _press),
                if (widget.type.hasPayMode) ...[
                  const SizedBox(height: 14),
                  PayModePicker(
                    value: _mode ?? PayMode.cash,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                ],
                const SizedBox(height: 20),
                if (showCustomer) TextField(
                  controller: _customer,
                  style: const TextStyle(fontSize: 22),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: widget.type.needsCustomer
                        ? s.customerName
                        : '${isExpense ? s.spentBy : s.customerName} ${s.optional}',
                    labelStyle: const TextStyle(fontSize: 18),
                    prefixIcon: Icon(isExpense ? Icons.badge_outlined : Icons.person),
                    suffixIcon: MicButton(
                      controller: _customer,
                      names: true,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _save(),
                ),
                if (showCustomer && suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in suggestions)
                        ActionChip(
                          avatar: const Icon(Icons.person_outline, size: 18),
                          label: Text(n, style: const TextStyle(fontSize: 17)),
                          onPressed: () => setState(() {
                            _customer.text = n;
                            _error = null;
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    labelText: '${s.note} ${s.optional}',
                    prefixIcon: const Icon(Icons.edit_note),
                    suffixIcon: MicButton(controller: _note, append: true),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 18, color: HisaabColors.moneyOut, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: color),
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 30),
                    label: Text(s.save, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.cancel, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 4),
                Text(s.escHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: mutedText(context))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// On-screen number pad for mouse or touch-screen counters.
class _Numpad extends StatelessWidget {
  const _Numpad({required this.onKey});
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['00', '0', 'back'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final k in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        height: 58,
                        // Keep keyboard focus in the amount box.
                        child: ExcludeFocus(
                          child: OutlinedButton(
                            onPressed: () => onKey(k),
                            child: k == 'back'
                                ? const Icon(Icons.backspace_outlined, size: 26)
                                : Text(k, style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Two big buttons: 💵 Cash | 📱 UPI.
class PayModePicker extends StatelessWidget {
  const PayModePicker({super.key, required this.value, required this.onChanged});
  final PayMode value;
  final ValueChanged<PayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    Widget half(PayMode m, IconData icon, String label, Color color) {
      final on = value == m;
      return Expanded(
        child: ExcludeFocus(
          child: Material(
            color: on ? color : color.withAlpha(22),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(m),
              child: SizedBox(
                height: 54,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: on ? Colors.white : color),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700, color: on ? Colors.white : color)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      half(PayMode.cash, Icons.payments_outlined, s.cash, HisaabColors.moneyIn),
      const SizedBox(width: 10),
      half(PayMode.upi, Icons.qr_code_2, s.upi, HisaabColors.payment),
    ]);
  }
}
