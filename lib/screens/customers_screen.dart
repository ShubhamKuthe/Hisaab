import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models/entry.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../utils/whatsapp.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/voice_input.dart';
import 'add_entry_screen.dart';

/// "Who owes me money" - every customer with their balance.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final q = _query.trim().toLowerCase();
    final list = state
        .balances()
        .where((b) => q.isEmpty || b.name.toLowerCase().contains(q))
        .toList();

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.whoOwes, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                StatCard(
                  label: s.totalDue,
                  amount: state.totalDue(),
                  color: HisaabColors.udhaar,
                ),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    labelText: s.search,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(s.noCustomers,
                          style: TextStyle(fontSize: 18, color: mutedText(context))),
                    ),
                  ),
                for (var i = 0; i < list.length; i++)
                  FadeSlideIn(
                    key: ValueKey(list[i].name),
                    delayMs: i < 10 ? i * 35 : 0,
                    child: _CustomerTile(balance: list[i]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.balance});
  final CustomerBalance balance;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final deva = state.devanagariDigits;
    final due = balance.duePaise;
    final (label, color) = due > 0
        ? (s.due, HisaabColors.udhaar)
        : due < 0
            ? (s.advance, HisaabColors.moneyIn)
            : (s.settled, HisaabColors.moneyIn);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: color.withAlpha(36),
          child: Text(
            balance.name.characters.first.toUpperCase(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        title: Text(balance.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
        subtitle: Text(label, style: TextStyle(fontSize: 15, color: color)),
        trailing: Text(
          due == 0 ? '✓' : formatRupees(due.abs(), devanagari: deva),
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: color),
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => CustomerDetailScreen(name: balance.name),
        )),
      ),
    );
  }
}

/// One customer's page: balance, quick buttons and full history.
class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.name});
  final String name;

  void _add(BuildContext context, EntryType type) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AddEntryScreen(type: type, customer: name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final due = state.dueFor(name);
    final history = state.entriesFor(name);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.f3): () => _add(context, EntryType.udhaarGiven),
        const SingleActivator(LogicalKeyboardKey.f4): () => _add(context, EntryType.paymentReceived),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  StatCard(
                    label: due > 0 ? s.due : (due < 0 ? s.advance : s.settled),
                    amount: due.abs(),
                    color: due > 0 ? HisaabColors.udhaar : HisaabColors.moneyIn,
                  ),
                  const SizedBox(height: 12),
                  _PhoneAndReminder(name: name, due: due),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: BigActionButton(
                          icon: HisaabColors.iconFor(EntryType.udhaarGiven),
                          label: s.udhaarGiven,
                          shortcut: 'F3',
                          color: HisaabColors.udhaar,
                          onTap: () => _add(context, EntryType.udhaarGiven),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BigActionButton(
                          icon: HisaabColors.iconFor(EntryType.paymentReceived),
                          label: s.paymentReceived,
                          shortcut: 'F4',
                          color: HisaabColors.payment,
                          onTap: () => _add(context, EntryType.paymentReceived),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(s.history, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final e in history) EntryTile(entry: e, showDate: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Customer's phone number (typed once) and the WhatsApp reminder button.
class _PhoneAndReminder extends StatefulWidget {
  const _PhoneAndReminder({required this.name, required this.due});
  final String name;
  final int due;

  @override
  State<_PhoneAndReminder> createState() => _PhoneAndReminderState();
}

class _PhoneAndReminderState extends State<_PhoneAndReminder> {
  TextEditingController? _phone;
  bool _editing = false;

  @override
  void dispose() {
    _phone?.dispose();
    super.dispose();
  }

  void _savePhone() {
    final state = AppScope.of(context);
    state.setCustomerPhone(widget.name, _phone!.text);
    setState(() => _editing = false);
  }

  Future<void> _remind() async {
    final state = AppScope.of(context);
    final s = state.s;
    final messenger = ScaffoldMessenger.of(context);
    final amount = formatRupees(widget.due, devanagari: state.devanagariDigits);
    final text = [
      s.reminderMsg(widget.name, amount),
      if ((state.shopUpi ?? '').isNotEmpty) s.payByUpi(state.shopUpi!),
      if ((state.shopName ?? '').isNotEmpty)
        '— ${state.shopName}${(state.shopPhone ?? '').isNotEmpty ? ' (${state.shopPhone})' : ''}',
    ].join('\n');
    final opened = await openWhatsApp(text, phone: state.phoneFor(widget.name));
    if (!opened) {
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(s.whatsappFailed, style: const TextStyle(fontSize: 16)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final phone = state.phoneFor(widget.name);
    final editing = _editing || phone == null;
    _phone ??= TextEditingController(text: phone ?? '');

    final phoneRow = editing
        ? TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 19),
            decoration: InputDecoration(
              labelText: '${s.customerPhone} ${s.optional}',
              prefixIcon: const Icon(Icons.phone),
              suffixIcon: IconButton(
                tooltip: s.save,
                icon: const Icon(Icons.check_circle, color: HisaabColors.moneyIn),
                onPressed: _savePhone,
              ),
            ),
            onSubmitted: (_) => _savePhone(),
          )
        : Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: const Icon(Icons.phone, color: HisaabColors.payment),
              title: Text(toDigits(phone, state.devanagariDigits), style: const TextStyle(fontSize: 19)),
              trailing: TextButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit, size: 20),
                label: Text(s.edit),
              ),
            ),
          );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      phoneRow,
      if (widget.due > 0) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25A244)),
            onPressed: _remind,
            icon: const Icon(Icons.chat, size: 26),
            label: Text(s.sendReminder, style: const TextStyle(fontSize: 19)),
          ),
        ),
      ],
    ]);
  }
}

/// Quick search (🔍 button or Ctrl+F). Two buttons next to the box choose
/// what to search: green = customers, red = people you paid (staff, suppliers).
/// Empty box = most recent people.
Future<void> showCustomerSearch(BuildContext context, {bool paidTo = false}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SearchDialog(startWithPaidTo: paidTo),
  );
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.startWithPaidTo});
  final bool startWithPaidTo;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _Hit {
  const _Hit(this.name, this.amount, this.label, this.color);
  final String name;
  final int amount;
  final String? label; // "Settled" etc. instead of an amount
  final Color color;
}

class _SearchDialogState extends State<_SearchDialog> {
  String _query = '';
  late bool _paidTo = widget.startWithPaidTo;
  final _focus = FocusNode();
  final _text = TextEditingController();

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  static String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  void _open(String name) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute<void>(
      builder: (_) => _paidTo ? PaidToDetailScreen(name: name) : CustomerDetailScreen(name: name),
    ));
  }

  /// Names starting with the text first, then names containing it.
  List<T> _match<T>(List<T> all, String Function(T) name, String q) {
    if (q.isEmpty) return all.take(8).toList();
    final starts = all.where((x) => _norm(name(x)).startsWith(q));
    final contains = all.where((x) => !_norm(name(x)).startsWith(q) && _norm(name(x)).contains(q));
    return [...starts, ...contains];
  }

  void _setMode(bool paidTo) {
    setState(() => _paidTo = paidTo);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final deva = state.devanagariDigits;
    final q = _norm(_query);

    final List<_Hit> hits;
    if (_paidTo) {
      hits = [
        for (final p in _match(state.paidToTotals(), (PaidToTotal p) => p.name, q))
          _Hit(p.name, p.totalPaise, null, HisaabColors.moneyOut),
      ];
    } else {
      final recentFirst = state.balances()..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
      hits = [
        for (final b in _match(recentFirst, (CustomerBalance b) => b.name, q))
          _Hit(b.name, b.duePaise.abs(), b.duePaise == 0 ? s.settled : null,
              b.duePaise > 0 ? HisaabColors.udhaar : HisaabColors.moneyIn),
      ];
    }

    // One switch with two equal halves: green = customers, red = paid to.
    Widget half({required bool paidTo, required IconData icon, required String label, required Color color}) {
      final on = _paidTo == paidTo;
      return Expanded(
        child: AnimatedContainer(
          duration: motion(context, 180),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: on ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _setMode(paidTo),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 20, color: on ? Colors.white : color),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: on ? Colors.white : color)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final narrow = MediaQuery.sizeOf(context).width < 640;
    final Widget searchField = TextField(
                    focusNode: _focus,
                    controller: _text,
                    autofocus: true,
                    style: const TextStyle(fontSize: 21),
                    decoration: InputDecoration(
                      hintText: _paidTo ? s.searchPaidTo : s.searchCustomer,
                      prefixIcon: Icon(Icons.search, size: 28,
                          color: _paidTo ? HisaabColors.moneyOut : HisaabColors.moneyIn),
                      suffixIcon: MicButton(
                        controller: _text,
                        names: true,
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                    onSubmitted: (_) {
                      if (hits.isNotEmpty) _open(hits.first.name);
                    },
                  );

    final modeSwitch = SizedBox(
      width: narrow ? double.infinity : 300,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(children: [
          half(paidTo: false, icon: Icons.person, label: s.customers, color: HisaabColors.moneyIn),
          half(paidTo: true, icon: Icons.store, label: s.paidTo, color: HisaabColors.moneyOut),
        ]),
      ),
    );

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phone: switch under the box. PC: same height, side by side.
              if (narrow) ...[
                searchField,
                const SizedBox(height: 8),
                SizedBox(height: 52, child: modeSwitch),
              ] else
                IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 10),
                    modeSwitch,
                  ]),
                ),
              const SizedBox(height: 10),
              if (hits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(q.isEmpty ? (_paidTo ? s.noPaidTo : s.noCustomers) : s.noMatch,
                      style: TextStyle(fontSize: 18, color: mutedText(context))),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: hits.length,
                    itemBuilder: (context, i) {
                      final h = hits[i];
                      return FadeSlideIn(
                        key: ValueKey('search-$_paidTo-${h.name}'),
                        delayMs: i < 8 ? i * 30 : 0,
                        durationMs: 220,
                        offsetY: 8,
                        child: ListTile(
                          onTap: () => _open(h.name),
                          leading: CircleAvatar(
                            backgroundColor: h.color.withAlpha(36),
                            child: _paidTo
                                ? Icon(Icons.store, color: h.color)
                                : Text(h.name.characters.first.toUpperCase(),
                                    style: TextStyle(color: h.color, fontWeight: FontWeight.w700)),
                          ),
                          title: Text(h.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                          subtitle: _paidTo
                              ? Text(s.totalPaid, style: TextStyle(fontSize: 14, color: mutedText(context)))
                              : null,
                          trailing: Text(
                            h.label ?? formatRupees(h.amount, devanagari: deva),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: h.color),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 4),
              Text('Enter = ↵  ·  Esc = ✕', style: TextStyle(fontSize: 12, color: mutedText(context))),
            ],
          ),
        ),
      ),
    );
  }
}

/// One person you paid (staff, supplier): total paid and every expense.
class PaidToDetailScreen extends StatelessWidget {
  const PaidToDetailScreen({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final list = state.expensesFor(name);
    final total = list.fold<int>(0, (sum, e) => sum + e.amountPaise);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Row(children: [
              const Icon(Icons.store, color: HisaabColors.moneyOut),
              const SizedBox(width: 10),
              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ]),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  StatCard(label: s.totalPaid, amount: total, color: HisaabColors.moneyOut),
                  const SizedBox(height: 20),
                  Text(s.history, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < list.length; i++)
                    FadeSlideIn(
                      key: ValueKey(list[i].id),
                      delayMs: i < 10 ? i * 30 : 0,
                      child: EntryTile(entry: list[i], showDate: true),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
