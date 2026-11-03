import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../security/pin.dart';
import '../utils/format.dart';
import '../widgets/logo.dart';
import '../widgets/motion.dart';
import '../widgets/pin_pad.dart';

/// First time: choose a PIN, type it again, then write down the recovery code.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _SetupStage { enter, confirm, code }

class _PinSetupScreenState extends State<PinSetupScreen> {
  _SetupStage _stage = _SetupStage.enter;
  String _first = '';
  String? _error;
  int _shakes = 0;
  final String _code = PinCrypto.newRecoveryCode();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;

    final Widget body = switch (_stage) {
      _SetupStage.enter => PinPad(
          key: const ValueKey('enter'),
          title: s.setPinTitle,
          subtitle: s.setPinHint,
          error: _error,
          shakeTrigger: _shakes,
          onCompleted: (v) => setState(() {
            _first = v;
            _error = null;
            _stage = _SetupStage.confirm;
          }),
        ),
      _SetupStage.confirm => PinPad(
          key: const ValueKey('confirm'),
          title: s.confirmPin,
          onCompleted: (v) => setState(() {
            if (v == _first) {
              _stage = _SetupStage.code;
            } else {
              _error = s.pinMismatch;
              _shakes++;
              _stage = _SetupStage.enter;
            }
          }),
        ),
      _SetupStage.code => _RecoveryCodeView(
          code: _code,
          onDone: () => state.setPin(_first, _code),
        ),
    };

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_stage != _SetupStage.code) ...[
              const HisaabLogo(size: 96),
              const SizedBox(height: 12),
            ],
            body,
          ]),
        ),
      ),
    );
  }
}

class _RecoveryCodeView extends StatelessWidget {
  const _RecoveryCodeView({required this.code, required this.onDone, this.warning});
  final String code;
  final VoidCallback onDone;

  /// Extra line in red, e.g. "Your old recovery code no longer works."
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final shown = toDigits('${code.substring(0, 4)}  ${code.substring(4)}', state.devanagariDigits);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit_note, size: 56, color: HisaabColors.brand),
          const SizedBox(height: 8),
          Text(s.recoveryTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: HisaabColors.udhaar.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HisaabColors.udhaar, width: 2),
            ),
            child: SelectableText(shown,
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 4)),
          ),
          const SizedBox(height: 18),
          Text(s.recoveryExplain, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
          if (warning != null) ...[
            const SizedBox(height: 10),
            Text(warning!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: HisaabColors.moneyOut)),
          ],
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.check, size: 28),
              label: Text(s.iWroteIt, style: const TextStyle(fontSize: 22)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every app start: enter the PIN. "Forgot PIN?" uses the recovery code.
class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

enum _UnlockStage { unlock, recovery, newPin, confirmNew }

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  _UnlockStage _stage = _UnlockStage.unlock;
  String? _error;
  String _recovery = '';
  String _first = '';
  int _shakes = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh the "try again in N seconds" countdown.
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
    final lockMsg = left == null ? null : s.tryAgainIn(left.inSeconds + 1);

    Widget backButton() => TextButton(
          onPressed: () => setState(() {
            _stage = _UnlockStage.unlock;
            _error = null;
          }),
          child: Text(s.back, style: const TextStyle(fontSize: 17)),
        );

    final Widget body = switch (_stage) {
      _UnlockStage.unlock => PinPad(
          key: const ValueKey('unlock'),
          shakeTrigger: _shakes,
          title: s.enterPin,
          subtitle: s.appName,
          enabled: left == null,
          error: lockMsg ?? _error,
          footer: TextButton(
            onPressed: () => setState(() {
              _stage = _UnlockStage.recovery;
              _error = null;
            }),
            child: Text(s.forgotPin, style: const TextStyle(fontSize: 17)),
          ),
          onCompleted: (v) {
            if (!state.unlock(v)) {
              setState(() {
                _error = s.wrongPin;
                _shakes++;
              });
            }
          },
        ),
      _UnlockStage.recovery => PinPad(
          key: const ValueKey('recovery'),
          shakeTrigger: _shakes,
          title: s.enterRecovery,
          length: 8,
          enabled: left == null,
          error: lockMsg ?? _error,
          footer: backButton(),
          onCompleted: (v) => setState(() {
            if (state.checkRecoveryCode(v)) {
              _recovery = v;
              _error = null;
              _stage = _UnlockStage.newPin;
            } else {
              _error = s.wrongRecovery;
              _shakes++;
            }
          }),
        ),
      _UnlockStage.newPin => PinPad(
          key: const ValueKey('newPin'),
          shakeTrigger: _shakes,
          title: s.newPinTitle,
          error: _error,
          footer: backButton(),
          onCompleted: (v) => setState(() {
            _first = v;
            _error = null;
            _stage = _UnlockStage.confirmNew;
          }),
        ),
      _UnlockStage.confirmNew => PinPad(
          key: const ValueKey('confirmNew'),
          title: s.confirmPin,
          footer: backButton(),
          onCompleted: (v) {
            if (v == _first) {
              state.setPin(v, _recovery); // same recovery code stays valid
            } else {
              setState(() {
                _error = s.pinMismatch;
                _shakes++;
                _stage = _UnlockStage.newPin;
              });
            }
          },
        ),
    };

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HisaabLogo(size: 96),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

/// Change PIN: current PIN -> new PIN -> confirm -> a brand-new recovery code.
/// The old recovery code stops working as soon as the new one is saved.
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

enum _ChangeStage { current, newPin, confirm, code }

class _ChangePinScreenState extends State<ChangePinScreen> {
  _ChangeStage _stage = _ChangeStage.current;
  String _first = '';
  String? _error;
  int _shakes = 0;
  final String _code = PinCrypto.newRecoveryCode();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _stage == _ChangeStage.current) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _fail(String message, _ChangeStage stage) => setState(() {
        _error = message;
        _shakes++;
        _stage = stage;
      });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final left = state.lockoutLeft();
    final lockMsg = left == null ? null : s.tryAgainIn(left.inSeconds + 1);

    final Widget body = switch (_stage) {
      _ChangeStage.current => PinPad(
          key: const ValueKey('current'),
          title: s.currentPin,
          enabled: left == null,
          error: lockMsg ?? _error,
          shakeTrigger: _shakes,
          onCompleted: (v) {
            if (state.checkPin(v)) {
              setState(() {
                _error = null;
                _stage = _ChangeStage.newPin;
              });
            } else {
              _fail(s.wrongPin, _ChangeStage.current);
            }
          },
        ),
      _ChangeStage.newPin => PinPad(
          key: const ValueKey('new'),
          title: s.newPinTitle,
          error: _error,
          shakeTrigger: _shakes,
          onCompleted: (v) => setState(() {
            _first = v;
            _error = null;
            _stage = _ChangeStage.confirm;
          }),
        ),
      _ChangeStage.confirm => PinPad(
          key: const ValueKey('confirm'),
          title: s.confirmPin,
          onCompleted: (v) {
            if (v == _first) {
              setState(() => _stage = _ChangeStage.code);
            } else {
              _fail(s.pinMismatch, _ChangeStage.newPin);
            }
          },
        ),
      _ChangeStage.code => _RecoveryCodeView(
          code: _code,
          warning: s.oldCodeInvalid,
          onDone: () {
            final messenger = ScaffoldMessenger.of(context);
            state.setPin(_first, _code); // new salt, new PIN, new recovery code
            Navigator.of(context).pop();
            messenger.showSnackBar(SnackBar(
              backgroundColor: HisaabColors.moneyIn,
              content: Text('✓ ${s.pinChanged}', style: const TextStyle(fontSize: 17)),
            ));
          },
        ),
    };

    return Scaffold(
      // No back button on the code screen: the new code must be written down.
      appBar: AppBar(
        automaticallyImplyLeading: _stage != _ChangeStage.code,
        title: Text(s.changePin, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PopScope(
        canPop: _stage != _ChangeStage.code,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AnimatedSwitcher(duration: motion(context, 220), child: body),
          ),
        ),
      ),
    );
  }
}
