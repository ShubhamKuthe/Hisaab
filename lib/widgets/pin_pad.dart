import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import 'motion.dart';

/// Big PIN entry pad: dots on top, large number buttons, and the keyboard's
/// number keys work too. Calls [onCompleted] once [length] digits are in,
/// then clears itself for the next try.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.length = 4,
    this.subtitle,
    this.error,
    this.enabled = true,
    this.footer,
    this.shakeTrigger,
  });

  final String title;
  final String? subtitle;
  final String? error;
  final int length;
  final bool enabled;
  final Widget? footer;

  /// Change this (e.g. a counter) to shake the dots after a wrong try.
  final Object? shakeTrigger;
  final void Function(String value) onCompleted;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _value = '';
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _add(String digit) {
    if (!widget.enabled || _value.length >= widget.length) return;
    setState(() => _value += digit);
    if (_value.length == widget.length) {
      final v = _value;
      // Let the last dot paint before checking.
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _value = '');
        widget.onCompleted(v);
      });
    }
  }

  void _backspace() {
    if (_value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      _add(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.length > 4 ? 18.0 : 24.0;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: mutedText(context))),
            ],
            const SizedBox(height: 24),
            Shake(
              trigger: widget.shakeTrigger ?? widget.error,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.length; i++)
                    AnimatedScale(
                      scale: i < _value.length ? 1.15 : 1,
                      duration: motion(context, 140),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: motion(context, 140),
                        width: dot,
                        height: dot,
                        margin: EdgeInsets.symmetric(horizontal: widget.length > 4 ? 6 : 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _value.length ? HisaabColors.brand : Colors.transparent,
                          border: Border.all(color: HisaabColors.brand, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: Center(
                child: Text(widget.error ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, color: HisaabColors.moneyOut, fontWeight: FontWeight.w600)),
              ),
            ),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', 'back'],
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    for (final k in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: SizedBox(
                            height: 66,
                            child: k.isEmpty
                                ? const SizedBox.shrink()
                                : ExcludeFocus(
                                    child: OutlinedButton(
                                      onPressed: !widget.enabled
                                          ? null
                                          : () {
                                              if (k == 'back') {
                                                _backspace();
                                              } else {
                                                _add(k);
                                              }
                                            },
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: k == 'back'
                                          ? const Icon(Icons.backspace_outlined, size: 28)
                                          : Text(k, style: const TextStyle(fontSize: 30)),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (widget.footer != null) ...[
              const SizedBox(height: 4),
              widget.footer!,
            ],
          ],
        ),
      ),
    );
  }
}
