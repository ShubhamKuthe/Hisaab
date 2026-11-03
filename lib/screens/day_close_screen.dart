import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../bills/receipt_output.dart';
import '../export/backup_actions.dart' show autoBackupIfDue;
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../utils/whatsapp.dart';

/// End of the day: one page with the day's totals, to send on WhatsApp
/// (to the owner / family) or print and keep with the cash.
class DayCloseScreen extends StatefulWidget {
  const DayCloseScreen({super.key});

  @override
  State<DayCloseScreen> createState() => _DayCloseScreenState();
}

class _DayCloseScreenState extends State<DayCloseScreen> {
  final _paperKey = GlobalKey();
  DateTime? _day;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Closing the day is a good moment to save a backup too.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = AppScope.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final file = await autoBackupIfDue(state, force: true);
      if (file != null && mounted) {
        messenger.showSnackBar(SnackBar(
          backgroundColor: HisaabColors.moneyIn,
          content: Text('✓ ${state.s.backupDone}', style: const TextStyle(fontSize: 16)),
        ));
      }
    });
  }

  DateTime get _today {
    final n = AppScope.of(context).now;
    return DateTime(n.year, n.month, n.day);
  }

  void _move(int days) => setState(() {
        final d = _day ?? _today;
        final next = DateTime(d.year, d.month, d.day + days);
        _day = next.isAfter(_today) ? _today : next;
      });

  List<(String, String)> _lines(AppState state, TodaySummary t) {
    final s = state.s;
    String m(int p) => formatRupees(p, devanagari: state.devanagariDigits);
    return [
      (s.sale, m(t.sales)),
      (s.paymentReceived, m(t.paymentsReceived)),
      ('= ${s.moneyIn}', m(t.moneyIn)),
      ('   ${s.cash}', m(t.cashIn)),
      ('   ${s.upi}', m(t.upiIn)),
      (s.expense, m(t.moneyOut)),
      (s.colNet, m(t.net)),
      (s.cashInDrawer, m(t.cashInHand)),
      (s.udhaarGiven, m(t.udhaarGiven)),
      ('${s.bills} · ${s.entriesCount}',
          toDigits('${t.bills} · ${t.count}', state.devanagariDigits)),
    ];
  }

  String _text(AppState state, DateTime day, TodaySummary t) {
    final s = state.s;
    final shop = state.shopName;
    return [
      '*${s.daySummary}* · ${formatDate(day, devanagari: state.devanagariDigits)}',
      if (shop != null) shop,
      '',
      for (final (k, v) in _lines(state, t)) '${k.trim()}: $v',
      '',
      '${s.totalDue}: ${formatRupees(state.totalDue(), devanagari: state.devanagariDigits)}',
      '— Hisaab',
    ].join('\n');
  }

  Future<void> _whatsApp(String text) async {
    final s = AppScope.of(context).s;
    final messenger = ScaffoldMessenger.of(context);
    if (!await openWhatsApp(text)) {
      messenger.showSnackBar(SnackBar(content: Text(s.whatsappFailed, style: const TextStyle(fontSize: 16))));
    }
  }

  Future<void> _copy(String text) async {
    final s = AppScope.of(context).s;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text('✓ ${s.copied}', style: const TextStyle(fontSize: 16))));
  }

  Future<void> _print(DateTime day) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final img = await captureReceipt(_paperKey);
      await printReceipt(img, name: 'Hisaab ${formatDate(day)}');
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
    final day = _day ?? _today;
    final t = state.summaryOn(day);
    final isToday = day == _today;
    final text = _text(state, day, t);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Row(children: [
              const Icon(Icons.nightlight_round, color: HisaabColors.brand),
              const SizedBox(width: 10),
              Text(s.closeDay, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ]),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton.filledTonal(
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isToday ? '${s.today} · ${formatDate(day, devanagari: state.devanagariDigits)}'
                        : formatDate(day, devanagari: state.devanagariDigits),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: isToday ? null : () => _move(1),
                    icon: const Icon(Icons.chevron_right, size: 30),
                  ),
                ]),
                const SizedBox(height: 18),
                FittedBox(
                  fit: BoxFit.scaleDown, // small phones
                  child: _Paper(
                  boundaryKey: _paperKey,
                  s: s,
                  shop: state.shopName ?? '',
                  date: formatDate(day, devanagari: state.devanagariDigits),
                  lines: _lines(state, t),
                  totalDue: formatRupees(state.totalDue(), devanagari: state.devanagariDigits),
                ),
                ),
                const SizedBox(height: 22),
                Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25A244), minimumSize: const Size(200, 56)),
                    onPressed: () => _whatsApp(text),
                    icon: const Icon(Icons.chat),
                    label: Text(s.shareWhatsapp, style: const TextStyle(fontSize: 18)),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: HisaabColors.bill, minimumSize: const Size(160, 56)),
                    onPressed: _busy ? null : () => _print(day),
                    icon: const Icon(Icons.print),
                    label: Text(s.print, style: const TextStyle(fontSize: 18)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(140, 56)),
                    onPressed: () => _copy(text),
                    icon: const Icon(Icons.copy),
                    label: Text(s.copy, style: const TextStyle(fontSize: 18)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// White "paper" version (what gets printed), whatever the theme.
class _Paper extends StatelessWidget {
  const _Paper({
    required this.boundaryKey,
    required this.s,
    required this.shop,
    required this.date,
    required this.lines,
    required this.totalDue,
  });
  final GlobalKey boundaryKey;
  final S s;
  final String shop;
  final String date;
  final List<(String, String)> lines;
  final String totalDue;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF111111);
    const faint = Color(0xFF555555);
    const rule = Divider(color: Color(0xFF999999), thickness: 1, height: 18);
    // Lines that are totals get bold.
    bool strong(String k) => k.startsWith('=') || k == s.colNet || k == s.cashInDrawer;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: 340,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: ink, fontSize: 16, height: 1.35),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (shop.isNotEmpty)
                Text(shop, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              Text(s.daySummary, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(date, textAlign: TextAlign.center, style: const TextStyle(color: faint)),
              rule,
              for (final (k, v) in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(k.startsWith('   ') ? '     ${k.trim()}' : k.trim(),
                          style: TextStyle(
                            fontWeight: strong(k) ? FontWeight.w800 : FontWeight.w400,
                            color: k.startsWith('   ') ? faint : ink,
                          )),
                    ),
                    Text(v, style: TextStyle(fontWeight: strong(k) ? FontWeight.w800 : FontWeight.w600)),
                  ]),
                ),
              rule,
              Row(children: [
                Expanded(child: Text(s.totalDue, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(totalDue, style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 10),
              const Text('Hisaab', textAlign: TextAlign.center, style: TextStyle(color: faint, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}
