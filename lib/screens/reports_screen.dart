import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'customers_screen.dart';

enum _Period { week, thisMonth, lastMonth }

/// How the shop is doing: this week / this month / last month.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.week;

  (DateTime, DateTime) _range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      _Period.week => (today.subtract(const Duration(days: 6)), today),
      _Period.thisMonth => (DateTime(now.year, now.month, 1), today),
      _Period.lastMonth => (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final deva = state.devanagariDigits;
    final (from, to) = _range(state.now);
    final r = state.report(from, to);
    final sum = r.summary;
    final best = r.bestDay;
    final avg = r.activeDays == 0 ? 0 : sum.moneyIn ~/ r.activeDays;
    String money(int p) => formatRupees(p, devanagari: deva);
    final dues = state.balances().where((b) => b.duePaise > 0).take(5).toList();

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ]),
        );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Row(children: [
              const Icon(Icons.bar_chart, color: HisaabColors.brand),
              const SizedBox(width: 10),
              Text(s.reports, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ]),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final (p, label) in [
                      (_Period.week, s.last7Days),
                      (_Period.thisMonth, s.thisMonth),
                      (_Period.lastMonth, s.lastMonth),
                    ])
                      ChoiceChip(
                        selected: _period == p,
                        showCheckmark: false,
                        selectedColor: HisaabColors.brand,
                        label: Text(label,
                            style: TextStyle(fontSize: 17, color: _period == p ? Colors.white : null)),
                        onSelected: (_) => setState(() => _period = p),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Text('${formatDate(from, devanagari: deva)}  –  ${formatDate(to, devanagari: deva)}',
                      style: TextStyle(fontSize: 15, color: mutedText(context))),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth >= 700 ? 4 : 2;
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 128,
                      ),
                      children: [
                        StatCard(
                          label: s.moneyIn,
                          amount: sum.moneyIn,
                          color: HisaabColors.moneyIn,
                          footer: '${s.cash} ${money(sum.cashIn)} · ${s.upi} ${money(sum.upiIn)}',
                        ),
                        StatCard(
                          label: s.moneyOut,
                          amount: sum.moneyOut,
                          color: HisaabColors.moneyOut,
                          footer: '${s.cash} ${money(sum.cashOut)} · ${s.upi} ${money(sum.upiOut)}',
                        ),
                        StatCard(
                          label: s.colNet,
                          amount: sum.net,
                          color: sum.net >= 0 ? HisaabColors.moneyIn : HisaabColors.moneyOut,
                        ),
                        StatCard(
                          label: s.udhaarGiven,
                          amount: sum.udhaarGiven,
                          color: HisaabColors.udhaar,
                          footer: '${s.paymentReceived} ${money(sum.paymentsReceived)}',
                        ),
                      ],
                    );
                  }),
                  section(
                    '${s.moneyIn} / ${s.moneyOut}',
                    sum.count == 0
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Center(
                              child: Text(s.noDataPeriod,
                                  style: TextStyle(fontSize: 17, color: mutedText(context))),
                            ),
                          )
                        : _DayChart(days: r.days, deva: deva),
                  ),
                  if (sum.count > 0)
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      if (best != null)
                        _Pill(
                          icon: Icons.emoji_events,
                          color: HisaabColors.brand,
                          text: '${s.bestDay}: ${formatDate(best.day, devanagari: deva)} · ${money(best.moneyIn)}',
                        ),
                      _Pill(
                        icon: Icons.trending_up,
                        color: HisaabColors.moneyIn,
                        text: '${s.dailyAverage}: ${money(avg)}',
                      ),
                      _Pill(
                        icon: Icons.receipt,
                        color: HisaabColors.bill,
                        text: '${s.bills}: ${toDigits('${sum.bills}', deva)} · ${s.entriesCount}: ${toDigits('${sum.count}', deva)}',
                      ),
                    ]),
                  if (r.topExpenses.isNotEmpty)
                    section(
                      s.topExpenses,
                      _BarList(
                        color: HisaabColors.moneyOut,
                        rows: [for (final e in r.topExpenses) (e.key ?? s.other, e.value)],
                        deva: deva,
                      ),
                    ),
                  if (dues.isNotEmpty)
                    section(
                      s.whoOwes,
                      _BarList(
                        color: HisaabColors.udhaar,
                        rows: [for (final b in dues) (b.name, b.duePaise)],
                        deva: deva,
                        onTap: (name) => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => CustomerDetailScreen(name: name),
                        )),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Name - bar - amount rows, longest bar = biggest amount.
class _BarList extends StatelessWidget {
  const _BarList({required this.color, required this.rows, required this.deva, this.onTap});
  final Color color;
  final List<(String, int)> rows;
  final bool deva;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<int>(1, (m, r) => math.max(m, r.$2));
    return Column(children: [
      for (final (name, value) in rows)
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap == null ? null : () => onTap!(name),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(children: [
              SizedBox(
                width: 150,
                child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: motion(context, 400),
                      curve: Curves.easeOutCubic,
                      height: 18,
                      width: math.max(4, c.maxWidth * value / max),
                      decoration: BoxDecoration(color: color.withAlpha(170), borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: Text(formatRupees(value, devanagari: deva),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Green (money in) and red (money out) bars for each day.
class _DayChart extends StatelessWidget {
  const _DayChart({required this.days, required this.deva});
  final List<DayTotal> days;
  final bool deva;

  @override
  Widget build(BuildContext context) {
    final grid = Theme.of(context).colorScheme.outlineVariant;
    final label = mutedText(context);
    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: grid),
      ),
      child: CustomPaint(
        painter: _ChartPainter(days: days, grid: grid, labelColor: label, deva: deva),
        size: Size.infinite,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.days, required this.grid, required this.labelColor, required this.deva});
  final List<DayTotal> days;
  final Color grid;
  final Color labelColor;
  final bool deva;

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 22.0; // room for day numbers
    final h = size.height - bottom;
    final maxV = days.fold<int>(1, (m, d) => math.max(m, math.max(d.moneyIn, d.moneyOut)));
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final n = days.length;
    final slot = size.width / n;
    final barW = math.min(18.0, slot * 0.36);
    final inPaint = Paint()..color = HisaabColors.moneyIn;
    final outPaint = Paint()..color = HisaabColors.moneyOut;
    final every = n <= 10 ? 1 : (n <= 20 ? 2 : 5);
    for (var i = 0; i < n; i++) {
      final d = days[i];
      final cx = slot * i + slot / 2;
      final inH = h * d.moneyIn / maxV;
      final outH = h * d.moneyOut / maxV;
      if (d.moneyIn > 0) {
        canvas.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(cx - barW - 1, h - inH, barW, inH),
                topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
            inPaint);
      }
      if (d.moneyOut > 0) {
        canvas.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(cx + 1, h - outH, barW, outH),
                topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
            outPaint);
      }
      if (i % every == 0 || i == n - 1) {
        final tp = TextPainter(
          text: TextSpan(text: toDigits('${d.day.day}', deva), style: TextStyle(color: labelColor, fontSize: 12)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, h + 5));
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.days != days || old.grid != grid || old.deva != deva;
}
