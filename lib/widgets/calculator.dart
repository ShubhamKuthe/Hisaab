import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models/entry.dart';
import '../screens/add_entry_screen.dart';
import '../utils/format.dart';

/// Small counter calculator for the home screen.
/// Works like a shop calculator: 120 + 45 + 30 =.
/// Click it once and the keyboard works too (numbers, + - * /, Enter, Backspace, Esc).
/// The green ₹ button turns the answer into a Sale entry.
class MiniCalculator extends StatefulWidget {
  const MiniCalculator({super.key, this.fill = false});

  /// Stretch the keys to fill all the height it is given (home screen, no scrolling).
  final bool fill;

  /// Smallest height that still works nicely in [fill] mode.
  static const minFillHeight = 300.0;

  @override
  State<MiniCalculator> createState() => _MiniCalculatorState();
}

class _MiniCalculatorState extends State<MiniCalculator> {
  final _focus = FocusNode();
  double? _acc; // running total
  String? _op; // '+', '−', '×', '÷'
  String _entry = ''; // number being typed
  String _history = ''; // small line above the answer
  bool _justEvaluated = false;
  bool _error = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double? get _entryValue => _entry.isEmpty ? null : double.tryParse(_entry);

  /// What the big line shows (and what "Sale" uses).
  double? get _value => _entryValue ?? _acc;

  double? _apply(double a, String op, double b) {
    switch (op) {
      case '+':
        return a + b;
      case '−':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        return b == 0 ? null : a / b;
    }
    return b;
  }

  void _press(String k) {
    setState(() {
      if (_error && k != 'C') _clear();
      switch (k) {
        case 'C':
          _clear();
        case 'back':
          if (_justEvaluated) {
            _clear();
          } else if (_entry.isNotEmpty) {
            _entry = _entry.substring(0, _entry.length - 1);
          }
        case '.':
          if (_justEvaluated) _startFresh();
          if (!_entry.contains('.')) _entry = _entry.isEmpty ? '0.' : '$_entry.';
        case '+' || '−' || '×' || '÷':
          _justEvaluated = false;
          final v = _entryValue;
          if (v != null) {
            if (_acc == null || _op == null) {
              _acc = v;
            } else {
              final r = _apply(_acc!, _op!, v);
              if (r == null) return _fail();
              _acc = r;
            }
            _entry = '';
          }
          if (_acc != null) _op = k;
        case '%':
          final v = _entryValue;
          if (v == null) return;
          // 500 + 10% = 550, like a normal shop calculator
          final r = (_acc != null && (_op == '+' || _op == '−')) ? _acc! * v / 100 : v / 100;
          _entry = _plain(r);
        case '=':
          final v = _entryValue;
          if (_acc == null || _op == null || v == null) return;
          final r = _apply(_acc!, _op!, v);
          if (r == null) return _fail();
          _history = '${_show(_acc!)} $_op ${_show(v)} =';
          _entry = _plain(r);
          _acc = null;
          _op = null;
          _justEvaluated = true;
        default: // a digit or '00'
          if (_justEvaluated) _startFresh();
          if (_entry == '0') _entry = '';
          if (_entry.isEmpty && k == '00') return;
          if (_entry.replaceAll('.', '').length + k.length > 12) return;
          _entry += k;
      }
    });
  }

  void _startFresh() {
    _entry = '';
    _history = '';
    _justEvaluated = false;
  }

  void _clear() {
    _acc = null;
    _op = null;
    _entry = '';
    _history = '';
    _justEvaluated = false;
    _error = false;
  }

  void _fail() {
    _clear();
    _error = true;
  }

  /// Number as plain text for further typing: 12.5, 300
  String _plain(double v) {
    final r = (v * 100).round() / 100;
    if (r == r.truncateToDouble()) return r.toInt().toString();
    return r.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  /// Number for display: 1,23,456.5 in the shop's own digits.
  String _show(double v) {
    final txt = _plain(v);
    final neg = txt.startsWith('-');
    final body = neg ? txt.substring(1) : txt;
    final dot = body.indexOf('.');
    final whole = int.parse(dot < 0 ? body : body.substring(0, dot));
    final frac = dot < 0 ? '' : body.substring(dot);
    final deva = AppScope.of(context).devanagariDigits;
    return toDigits('${neg ? '-' : ''}${groupIndian(whole)}$frac', deva);
  }

  String _bigLine() {
    if (_error) return '—';
    if (_entry.isNotEmpty) {
      // keep what the user typed (e.g. "12." while typing)
      final dot = _entry.indexOf('.');
      final whole = int.tryParse(dot < 0 ? _entry : _entry.substring(0, dot)) ?? 0;
      final frac = dot < 0 ? '' : _entry.substring(dot);
      return toDigits('${groupIndian(whole)}$frac', AppScope.of(context).devanagariDigits);
    }
    return _acc == null ? toDigits('0', AppScope.of(context).devanagariDigits) : _show(_acc!);
  }

  String _smallLine() {
    if (_acc != null && _op != null) return '${_show(_acc!)} $_op';
    return _history;
  }

  void _useAsSale() {
    final v = _value;
    if (v == null || v <= 0) return;
    final rupees = v.round();
    if (rupees <= 0) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AddEntryScreen(type: EntryType.sale, initialAmount: '$rupees'),
    ));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _press('=');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _press('back');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.delete) {
      _press('C');
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch == null || ch.isEmpty) return KeyEventResult.ignored;
    final c = toLatinDigits(ch);
    const map = {'+': '+', '-': '−', '*': '×', 'x': '×', 'X': '×', '/': '÷', '=': '=', '%': '%', '.': '.'};
    if (RegExp(r'^[0-9]$').hasMatch(c)) {
      _press(c);
      return KeyEventResult.handled;
    }
    final m = map[c];
    if (m != null) {
      _press(m);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored; // let F1, F2... reach the home screen
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deva = AppScope.of(context).devanagariDigits;
    final canSell = (_value ?? 0) >= 1 && !_error;

    Widget key(String k, {Color? color, Color? text, int flex = 1, Widget? child}) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: SizedBox(
              height: widget.fill ? null : 44,
              child: ExcludeFocus(
                child: Material(
                  color: color ?? scheme.onSurface.withAlpha(16),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _focus.requestFocus();
                      _press(k);
                    },
                    child: Center(
                      child: child ??
                          Text(
                            RegExp(r'^[0-9]+$').hasMatch(k) ? toDigits(k, deva) : k,
                            style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                color: text ?? scheme.onSurface),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    // In fill mode each key row shares the free height equally.
    Widget row(List<Widget> keys) {
      final r = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: keys);
      return widget.fill ? Expanded(child: r) : IntrinsicHeight(child: r);
    }

    Widget opKey(String k) =>
        key(k, color: HisaabColors.brand.withAlpha(_op == k && _entry.isEmpty ? 90 : 38), text: HisaabColors.brand);

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: _focus,
        builder: (context, _) => GestureDetector(
          onTap: _focus.requestFocus,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(9, 10, 9, 9),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focus.hasFocus ? HisaabColors.brand : scheme.outlineVariant,
                width: _focus.hasFocus ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(Icons.calculate_outlined, color: mutedText(context), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_smallLine(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, color: mutedText(context))),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(_bigLine(),
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                row([
                  key('C', text: HisaabColors.moneyOut),
                  key('back', child: Icon(Icons.backspace_outlined, size: 20, color: scheme.onSurface)),
                  key('%', text: HisaabColors.brand),
                  opKey('÷'),
                ]),
                row([key('7'), key('8'), key('9'), opKey('×')]),
                row([key('4'), key('5'), key('6'), opKey('−')]),
                row([key('1'), key('2'), key('3'), opKey('+')]),
                row([
                  key('00'),
                  key('0'),
                  key('.'),
                  key('=', color: HisaabColors.brand, text: Colors.white),
                ]),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: canSell ? 1 : 0.4,
                    child: ExcludeFocus(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: HisaabColors.moneyIn,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: canSell ? _useAsSale : null,
                        icon: Icon(HisaabColors.iconFor(EntryType.sale)),
                        label: Text(AppScope.of(context).s.sale, style: const TextStyle(fontSize: 17)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
