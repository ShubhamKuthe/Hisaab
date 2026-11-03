import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../export/backup_actions.dart';

/// Wrap the home screen with this: once when the app opens and then every
/// 15 minutes it makes the daily backup if one hasn't been made today.
class AutoBackupRunner extends StatefulWidget {
  const AutoBackupRunner({super.key, required this.child});
  final Widget child;

  @override
  State<AutoBackupRunner> createState() => _AutoBackupRunnerState();
}

class _AutoBackupRunnerState extends State<AutoBackupRunner> {
  Timer? _timer;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_running || !mounted) return;
    _running = true;
    final state = AppScope.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final file = await autoBackupIfDue(state);
    _running = false;
    if (file != null && mounted) {
      messenger?.showSnackBar(SnackBar(
        backgroundColor: HisaabColors.moneyIn,
        content: Text('✓ ${state.s.autoBackupDone}', style: const TextStyle(fontSize: 16)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
