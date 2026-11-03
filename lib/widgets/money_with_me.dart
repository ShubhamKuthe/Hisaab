import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../utils/format.dart';
import 'motion.dart';
import 'pin_pad.dart';

/// "Money with me": everything that came in minus everything spent, all time.
/// Hidden behind the shop's 4-digit PIN so a customer at the counter
/// can't see it. Hides itself again after 30 seconds.
class MoneyWithMeCard extends StatefulWidget {
  const MoneyWithMeCard({super.key});

  @override
  State<MoneyWithMeCard> createState() => _MoneyWithMeCardState();
}

class _MoneyWithMeCardState extends State<MoneyWithMeCard> {
  static const _showFor = Duration(seconds: 30);
  bool _shown = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _hide() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _shown = false);
  }

  Future<void> _tap() async {
    if (_shown) {
      _hide();
      return;
    }
    final state = AppScope.of(context);
    final ok = !state.hasPin ||
        await showDialog<bool>(
              context: context,
              builder: (_) => const _PinCheckDialog(),
            ) ==
            true;
    if (!ok || !mounted) return;
    setState(() => _shown = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(_showFor, _hide);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    const color = HisaabColors.brand;
    final total = state.moneyWithMe();
    final valueColor = total < 0 ? HisaabColors.moneyOut : color;

    return Material(
      color: color.withAlpha(28),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _tap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: color, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.moneyWithMe,
                        style: const TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: motion(context, 220),
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                      child: _shown
                          ? FittedBox(
                              key: const ValueKey('shown'),
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatRupees(total, devanagari: state.devanagariDigits),
                                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: valueColor),
                              ),
                            )
                          : Text(
                              '₹ • • • • •',
                              key: const ValueKey('hidden'),
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: color.withAlpha(150),
                                  letterSpacing: 2),
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(_shown ? s.moneyWithMeHint : s.tapToSee,
                        style: TextStyle(fontSize: 13, color: mutedText(context))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withAlpha(40), shape: BoxShape.circle),
                child: Tooltip(
                  message: _shown ? s.hide : s.tapToSee,
                  child: Icon(_shown ? Icons.visibility_off : Icons.lock_outline, color: color, size: 26),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for the shop PIN. Wrong tries count towards the normal lockout.
class _PinCheckDialog extends StatefulWidget {
  const _PinCheckDialog();

  @override
  State<_PinCheckDialog> createState() => _PinCheckDialogState();
}

class _PinCheckDialogState extends State<_PinCheckDialog> {
  String? _error;
  int _shakes = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh the "try again in …" countdown while locked out.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final left = state.lockoutLeft();
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinPad(
              title: s.enterPin,
              subtitle: s.moneyWithMe,
              enabled: left == null,
              error: left == null ? _error : s.tryAgainIn(left.inSeconds + 1),
              shakeTrigger: _shakes,
              onCompleted: (v) {
                if (state.checkPin(v)) {
                  Navigator.of(context).pop(true);
                } else {
                  setState(() {
                    _error = s.wrongPin;
                    _shakes++;
                  });
                }
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.cancel, style: const TextStyle(fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }
}
