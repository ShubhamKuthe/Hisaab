import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../export/backup_actions.dart';
import '../models/entry.dart';
import '../utils/format.dart';
import '../widgets/logo.dart';
import '../widgets/money_with_me.dart';
import '../widgets/auto_backup.dart';
import '../widgets/speak_entry.dart';
import '../widgets/backup_card.dart';
import '../widgets/calculator.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'add_entry_screen.dart';
import 'bill_screen.dart';
import 'customers_screen.dart';
import 'language_screen.dart';
import 'pin_screens.dart';
import 'day_close_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _add(BuildContext context, EntryType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AddEntryScreen(type: type)),
    );
  }

  void _customers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CustomersScreen()),
    );
  }

  void _reports(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReportsScreen()));
  }

  void _closeDay(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DayCloseScreen()));
  }

  void _bill(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BillScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final simple = state.simpleMode;
    final deva = state.devanagariDigits;
    final sum = state.today();
    final todays = state.todayEntries();

    // [h] = fixed button height when the screen must fit without scrolling.
    List<Widget> buildActions([double? h]) => <Widget>[
      BigActionButton(
          icon: HisaabColors.iconFor(EntryType.sale),
          label: s.sale,
          shortcut: 'F1',
          color: HisaabColors.moneyIn,
          height: h,
          onTap: () => _add(context, EntryType.sale)),
      BigActionButton(
          icon: HisaabColors.iconFor(EntryType.expense),
          label: s.expense,
          shortcut: 'F2',
          color: HisaabColors.moneyOut,
          height: h,
          onTap: () => _add(context, EntryType.expense)),
      if (!simple) ...[
        BigActionButton(
            icon: Icons.receipt,
            label: s.makeBill,
            shortcut: 'F6',
            color: HisaabColors.bill,
            height: h,
          onTap: () => _bill(context)),
        BigActionButton(
            icon: HisaabColors.iconFor(EntryType.udhaarGiven),
            label: s.udhaarGiven,
            shortcut: 'F3',
            color: HisaabColors.udhaar,
            height: h,
          onTap: () => _add(context, EntryType.udhaarGiven)),
        BigActionButton(
            icon: HisaabColors.iconFor(EntryType.paymentReceived),
            label: s.paymentReceived,
            shortcut: 'F4',
            color: HisaabColors.payment,
            height: h,
          onTap: () => _add(context, EntryType.paymentReceived)),
        BigActionButton(
            icon: Icons.people_alt,
            label: s.whoOwes,
            shortcut: 'F5',
            color: HisaabColors.brand,
            height: h,
          onTap: () => _customers(context)),
      ],
        ];
    final actions = buildActions();

    final stats = GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: simple ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 124,
      ),
      children: [
        StatCard(
            label: s.moneyIn,
            amount: sum.moneyIn,
            color: HisaabColors.moneyIn,
            footer: '${s.cash} ${formatRupees(sum.cashIn, devanagari: deva)} · '
                '${s.upi} ${formatRupees(sum.upiIn, devanagari: deva)}'),
        StatCard(
            label: s.moneyOut,
            amount: sum.moneyOut,
            color: HisaabColors.moneyOut,
            footer: '${s.cashInDrawer} ${formatRupees(sum.cashInHand, devanagari: deva)}'),
        StatCard(
            label: s.netToday,
            amount: sum.net,
            color: sum.net >= 0 ? HisaabColors.moneyIn : HisaabColors.moneyOut),
        if (!simple)
          StatCard(
              label: s.totalDue,
              amount: state.totalDue(),
              color: HisaabColors.udhaar,
              onTap: () => _customers(context)),
      ],
    );

    final entriesHeader = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text('${s.todaysEntries}  ·  ${formatDate(DateTime.now(), devanagari: deva)}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    );
    final emptyNote = Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(s.noEntries, style: TextStyle(fontSize: 18, color: mutedText(context))),
      ),
    );

    // Round saffron mic: say the whole entry ("Ram ko 200 udhaar").
    final speakButton = Tooltip(
      message: '${s.speakEntry} (F8)',
      child: PressableScale(
        child: Material(
          color: HisaabColors.brand,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => showSpeakEntry(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                  mainAxisSize: simple ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                const Icon(Icons.mic, color: Colors.white, size: 30),
                if (simple) ...[
                  const SizedBox(width: 10),
                  Text(s.speakEntry,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );

    // Big, easy "search customer" bar (Advanced mode) + the mic.
    final searchBar = simple
        ? Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Expanded(child: speakButton)]))
        : Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Expanded(child: PressableScale(
              scale: 0.98,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => showCustomerSearch(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(children: [
                      const Icon(Icons.person_search, color: HisaabColors.brand, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.searchCustomer,
                            style: TextStyle(fontSize: 19, color: mutedText(context))),
                      ),
                      Text('Ctrl+F', style: TextStyle(fontSize: 13, color: mutedText(context))),
                    ]),
                  ),
                ),
              ),
              )),
              const SizedBox(width: 10),
              speakButton,
            ]),
          );

    // Buttons slide in/out smoothly when switching Simple <-> Advanced.
    Widget actionColumn(double gap, [double? h]) => AnimatedSize(
          duration: motion(context, 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++)
                FadeSlideIn(
                  key: ValueKey('action-$i-$simple'),
                  delayMs: i * 45,
                  child: Padding(padding: EdgeInsets.only(bottom: gap), child: buildActions(h)[i]),
                ),
            ],
          ),
        );

    // New entries fade in; the first few on screen arrive one after another.
    List<Widget> entryTiles() => [
          for (var i = 0; i < todays.length; i++)
            FadeSlideIn(
              key: ValueKey(todays[i].id),
              delayMs: i < 8 ? i * 35 : 0,
              child: EntryTile(entry: todays[i]),
            ),
        ];

    final body = LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 420,
              child: LayoutBuilder(builder: (context, lc) {
                // Fit buttons + backup + calculator into the window, no scrolling.
                const pad = 16.0, gap = 10.0, backupH = 60.0, calcGap = 10.0;
                final n = actions.length;
                final free = lc.maxHeight - pad * 2 - backupH - calcGap;
                const calcMin = MiniCalculator.minFillHeight;
                final btnH = ((free - calcMin) / n - gap).clamp(52.0, 76.0);
                final fits = free - n * (btnH + gap) >= calcMin;
                if (!fits) {
                  // Very small window: fall back to scrolling.
                  return ListView(
                    padding: const EdgeInsets.all(pad),
                    children: [
                      actionColumn(gap, 52),
                      const BackupCard(),
                      const SizedBox(height: calcGap),
                      const MiniCalculator(),
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      actionColumn(gap, btnH),
                      const BackupCard(),
                      const SizedBox(height: calcGap),
                      // Fills what is left; capped so keys don't get silly-big.
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 520),
                            child: const MiniCalculator(fill: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  searchBar,
                  stats,
                  const SizedBox(height: 12),
                  const MoneyWithMeCard(),
                  const SizedBox(height: 12),
                  entriesHeader,
                  if (todays.isEmpty) emptyNote,
                  ...entryTiles(),
                ],
              ),
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          searchBar,
          stats,
          const SizedBox(height: 12),
          const MoneyWithMeCard(),
          const SizedBox(height: 16),
          actionColumn(10),
          const BackupCard(),
          const SizedBox(height: 12),
          const MiniCalculator(),
          const SizedBox(height: 8),
          entriesHeader,
          if (todays.isEmpty) emptyNote,
          ...entryTiles(),
        ],
      );
    });

    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.f1): () => _add(context, EntryType.sale),
      const SingleActivator(LogicalKeyboardKey.f2): () => _add(context, EntryType.expense),
      const SingleActivator(LogicalKeyboardKey.f9): () => runBackup(context),
      const SingleActivator(LogicalKeyboardKey.f8): () => showSpeakEntry(context),
      const SingleActivator(LogicalKeyboardKey.f7): () => _reports(context),
      const SingleActivator(LogicalKeyboardKey.f10): () => _closeDay(context),
      if (!simple) ...{
        const SingleActivator(LogicalKeyboardKey.f3): () => _add(context, EntryType.udhaarGiven),
        const SingleActivator(LogicalKeyboardKey.f4): () => _add(context, EntryType.paymentReceived),
        const SingleActivator(LogicalKeyboardKey.f5): () => _customers(context),
        const SingleActivator(LogicalKeyboardKey.f6): () => _bill(context),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => showCustomerSearch(context),
      },
    };

    // Phone-sized screen: keep the top bar short, the rest goes in a ⋮ menu.
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final phoneActions = <Widget>[
      if (state.hasPin)
        IconButton(tooltip: s.lock, icon: const Icon(Icons.lock_outline), onPressed: state.lock),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (v) {
          final nav = Navigator.of(context);
          switch (v) {
            case 'mode':
              state.setSimpleMode(!simple);
            case 'reports':
              _reports(context);
            case 'close':
              _closeDay(context);
            case 'theme':
              state.cycleTheme();
            case 'pin':
              nav.push(MaterialPageRoute<void>(builder: (_) => const ChangePinScreen()));
            case 'lang':
              nav.push(MaterialPageRoute<void>(builder: (_) => const LanguageScreen()));
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'mode',
            child: ListTile(
              leading: Icon(simple ? Icons.tune : Icons.view_agenda_outlined),
              title: Text(simple ? s.advancedMode : s.simpleMode),
            ),
          ),
          PopupMenuItem(value: 'reports', child: ListTile(leading: const Icon(Icons.bar_chart), title: Text(s.reports))),
          PopupMenuItem(
              value: 'close', child: ListTile(leading: const Icon(Icons.nightlight_round), title: Text(s.closeDay))),
          PopupMenuItem(
            value: 'theme',
            child: ListTile(
              leading: Icon(switch (state.themeMode) {
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
                ThemeMode.system => Icons.brightness_auto,
              }),
              title: Text(s.themeLabel(state.themeMode)),
            ),
          ),
          PopupMenuItem(value: 'pin', child: ListTile(leading: const Icon(Icons.key), title: Text(s.changePin))),
          PopupMenuItem(value: 'lang', child: ListTile(leading: const Icon(Icons.translate), title: Text(s.language))),
        ],
      ),
    ];

    return AutoBackupRunner(
      child: CallbackShortcuts(
      bindings: bindings,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: narrow ? 12 : 20,
            title: Row(
              children: [
                const HisaabLogo(size: 36),
                const SizedBox(width: 10),
                Text(s.appName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                if (!narrow) const SizedBox(width: 14),
                if (!narrow) Flexible(
                  child: Text(s.tagline,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: mutedText(context))),
                ),
              ],
            ),
            actions: narrow ? phoneActions : [
              Tooltip(
                message: s.modeHint,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: true, label: Text(s.simpleMode, style: const TextStyle(fontSize: 16))),
                    ButtonSegment(value: false, label: Text(s.advancedMode, style: const TextStyle(fontSize: 16))),
                  ],
                  selected: {simple},
                  onSelectionChanged: (v) => state.setSimpleMode(v.first),
                ),
              ),
              const SizedBox(width: 8),
              if (!simple)
                IconButton(
                  tooltip: '${s.searchCustomer} (Ctrl+F)',
                  icon: const Icon(Icons.person_search),
                  onPressed: () => showCustomerSearch(context),
                ),
              IconButton(
                tooltip: '${s.reports} (F7)',
                icon: const Icon(Icons.bar_chart),
                onPressed: () => _reports(context),
              ),
              IconButton(
                tooltip: '${s.closeDay} (F10)',
                icon: const Icon(Icons.nightlight_round),
                onPressed: () => _closeDay(context),
              ),
              IconButton(
                tooltip: s.themeLabel(state.themeMode),
                icon: Icon(switch (state.themeMode) {
                  ThemeMode.light => Icons.light_mode,
                  ThemeMode.dark => Icons.dark_mode,
                  ThemeMode.system => Icons.brightness_auto,
                }),
                onPressed: state.cycleTheme,
              ),
              IconButton(
                tooltip: s.changePin,
                icon: const Icon(Icons.key),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ChangePinScreen()),
                ),
              ),
              IconButton(
                tooltip: s.lock,
                icon: const Icon(Icons.lock_outline),
                onPressed: state.lock,
              ),
              IconButton(
                tooltip: s.language,
                icon: const Icon(Icons.translate),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LanguageScreen()),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              if (state.saveFailed)
                MaterialBanner(
                  backgroundColor: const Color(0xFFFFEBEE),
                  content: Text(s.saveFailed, style: const TextStyle(fontSize: 16)),
                  actions: const [SizedBox.shrink()],
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
