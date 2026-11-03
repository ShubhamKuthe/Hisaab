import 'package:flutter/material.dart';

import '../app.dart';
import '../screens/add_entry_screen.dart';
import '../screens/bill_screen.dart';
import '../models/entry.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import 'motion.dart';

/// A big, colourful button with an icon, a label and its keyboard shortcut.
class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.shortcut,
    this.height,
  });

  /// Fixed height so the home screen can squeeze buttons to fit (no scrolling).
  final double? height;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    return PressableScale(child: _button());
  }

  Widget _button() {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: height == null ? 18 : 0),
          child: Row(
            children: [
              Icon(icon, size: height == null ? 40 : (height! * 0.5).clamp(24.0, 40.0), color: Colors.white),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: height == null ? 24 : (height! * 0.32).clamp(18.0, 24.0),
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              if (shortcut != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(shortcut!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A coloured number box: "Money in ₹4,500".
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    this.onTap,
    this.footer,
  });

  final String label;
  final int amount; // paise, counts smoothly when it changes
  final Color color;
  final VoidCallback? onTap;

  /// Small line under the amount, e.g. "Cash ₹500 · UPI ₹200".
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(28),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedMoney(
                  paise: amount,
                  devanagari: AppScope.of(context).devanagariDigits,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color),
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: 2),
                Text(footer!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: mutedText(context))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the book.
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, this.showDate = false});
  final Entry entry;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final deva = state.devanagariDigits;
    final color = HisaabColors.forType(entry.type);
    final when = showDate
        ? '${formatDate(entry.createdAt, devanagari: deva)}  ${formatTime(entry.createdAt, devanagari: deva)}'
        : formatTime(entry.createdAt, devanagari: deva);
    final showNames = !state.simpleMode;
    final subtitle = [
      if (entry.billNo != null) toDigits('${s.billNo} ${entry.billNo}', deva),
      if (showNames && entry.customer != null) entry.customer!,
      if (entry.note != null) entry.note!,
      if (entry.type.hasPayMode && entry.payMode == PayMode.upi) s.upi,
      when,
    ].join('  ·  ');

    return ListTile(
      // Bills open the receipt; anything else opens to be fixed.
      onTap: entry.isBill
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => BillViewScreen(entry: entry),
              ))
          : () => AddEntryScreen.edit(context, entry),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: color.withAlpha(36),
        child: Icon(HisaabColors.iconFor(entry.type), color: color),
      ),
      title: Text(s.typeLabel(entry.type),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatRupees(entry.amountPaise, devanagari: deva),
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: color)),
          IconButton(
            tooltip: s.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => deleteWithUndo(context, state, entry),
          ),
        ],
      ),
    );
  }
}

/// Deletes straight away and shows "Deleted · Undo" for 8 seconds.
void deleteWithUndo(BuildContext context, AppState state, Entry entry) {
  final s = state.s;
  final messenger = ScaffoldMessenger.of(context);
  state.deleteEntry(entry.id);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 8),
    content: Text(
      '🗑 ${s.deleted}: ${s.typeLabel(entry.type)} '
      '${formatRupees(entry.amountPaise, devanagari: state.devanagariDigits)}',
      style: const TextStyle(fontSize: 17),
    ),
    action: SnackBarAction(
      label: s.undo,
      textColor: HisaabColors.brand,
      onPressed: () => state.restoreEntry(entry),
    ),
  ));
}
