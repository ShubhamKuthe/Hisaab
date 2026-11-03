import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../models/entry.dart';
import '../screens/add_entry_screen.dart';
import '../utils/format.dart';
import '../voice/entry_parser.dart';
import 'voice_input.dart';

/// "Speak an entry": say "Ram ko 200 udhaar" and the whole entry is filled in.
/// The shopkeeper always sees what was understood before it is saved.
Future<void> showSpeakEntry(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _SpeakEntryDialog(),
    );

enum _Stage { listening, understood, failed }

class _SpeakEntryDialog extends StatefulWidget {
  const _SpeakEntryDialog();

  @override
  State<_SpeakEntryDialog> createState() => _SpeakEntryDialogState();
}

class _SpeakEntryDialogState extends State<_SpeakEntryDialog> {
  _Stage _stage = _Stage.listening;
  String _words = '';
  ParsedEntry? _parsed;
  late EntryType _type;
  PayMode? _mode;
  String? _failText;

  @override
  void initState() {
    super.initState();
    Voice.active.addListener(_onVoiceChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    Voice.active.removeListener(_onVoiceChange);
    if (Voice.active.value == this) Voice.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!mounted) return;
    final state = AppScope.of(context);
    setState(() {
      _stage = _Stage.listening;
      _words = '';
      _parsed = null;
      _failText = null;
    });
    final ok = await Voice.start(
      this,
      state.lang ?? AppLang.mr,
      (w) {
        if (mounted) setState(() => _words = w);
      },
      onFinal: (w) => _understand(w),
    );
    if (!ok && mounted) {
      setState(() {
        _stage = _Stage.failed;
        _failText = state.s.voiceUnavailable;
      });
    }
  }

  /// Listening stopped without a final result (silence / timeout).
  void _onVoiceChange() {
    if (!mounted || Voice.active.value != null || _stage != _Stage.listening) return;
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _stage == _Stage.listening) _understand(_words);
    });
  }

  void _understand(String words) {
    if (!mounted || _stage != _Stage.listening) return;
    final s = AppScope.of(context).s;
    if (words.trim().isEmpty) {
      setState(() {
        _stage = _Stage.failed;
        _failText = s.didntCatch;
      });
      return;
    }
    final p = EntryParser.parse(words);
    setState(() {
      _words = words;
      _parsed = p;
      _type = p.type;
      _mode = p.mode;
      _stage = p.amountPaise == null ? _Stage.failed : _Stage.understood;
      if (p.amountPaise == null) _failText = s.didntCatch;
    });
  }

  String? get _name => _parsed?.name ?? (_type.needsCustomer ? _parsed?.note : null);
  String? get _note => _type.needsCustomer ? null : (_parsed?.note ?? _parsed?.name);

  bool get _canSave =>
      _parsed?.amountPaise != null && (!_type.needsCustomer || (_name ?? '').isNotEmpty);

  void _save() {
    final state = AppScope.of(context);
    final s = state.s;
    final messenger = ScaffoldMessenger.of(context);
    final p = _parsed!;
    final mode = _type.hasPayMode ? (_mode ?? state.lastPayMode) : null;
    state.addEntry(
      type: _type,
      amountPaise: p.amountPaise!,
      customer: _type.needsCustomer ? _name : null,
      note: _note,
      mode: mode,
    );
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      backgroundColor: HisaabColors.forType(_type),
      content: Text(
        '✓ ${s.saved}: ${s.typeLabel(_type)} ${formatRupees(p.amountPaise!, devanagari: state.devanagariDigits)}'
        '${_name != null && _type.needsCustomer ? ' · $_name' : ''}'
        '${mode == null ? '' : ' · ${mode == PayMode.upi ? s.upi : s.cash}'}',
        style: const TextStyle(fontSize: 18),
      ),
    ));
  }

  void _edit() {
    final nav = Navigator.of(context);
    final p = _parsed;
    nav.pop();
    nav.push(MaterialPageRoute<void>(
      builder: (_) => AddEntryScreen(
        type: _type,
        customer: _type.needsCustomer ? _name : null,
        initialAmount: p?.amountPaise == null ? null : '${p!.amountPaise! ~/ 100}',
        initialNote: _note,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final deva = state.devanagariDigits;

    final Widget body = switch (_stage) {
      _Stage.listening => Column(mainAxisSize: MainAxisSize.min, children: [
          const _PulsingMic(),
          const SizedBox(height: 16),
          Text(s.listening, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(_words.isEmpty ? s.speakExamples : '“$_words”',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: _words.isEmpty ? 16 : 22,
                  color: _words.isEmpty ? mutedText(context) : null,
                  fontWeight: _words.isEmpty ? FontWeight.w400 : FontWeight.w600)),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => Voice.stop(),
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(s.done, style: const TextStyle(fontSize: 17)),
          ),
        ]),
      _Stage.failed => Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.mic_off, size: 54, color: HisaabColors.moneyOut),
          const SizedBox(height: 12),
          if (_words.isNotEmpty) ...[
            Text('${s.heard}: “$_words”', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
          ],
          Text(_failText ?? s.didntCatch,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, color: HisaabColors.moneyOut)),
          const SizedBox(height: 8),
          Text(s.speakExamples, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: mutedText(context))),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: HisaabColors.brand),
              onPressed: _listen,
              icon: const Icon(Icons.mic),
              label: Text(s.tryAgain, style: const TextStyle(fontSize: 17)),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
          ]),
        ]),
      _Stage.understood => _understoodView(s, deva),
    };

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _understoodView(S s, bool deva) {
    final p = _parsed!;
    final color = HisaabColors.forType(_type);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${s.heard}: “$_words”', style: TextStyle(fontSize: 15, color: mutedText(context))),
      const SizedBox(height: 14),
      // The type, as four small buttons so a wrong guess is one tap to fix.
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in EntryType.values)
          ChoiceChip(
            selected: _type == t,
            showCheckmark: false,
            selectedColor: HisaabColors.forType(t),
            avatar: Icon(HisaabColors.iconFor(t),
                size: 18, color: _type == t ? Colors.white : HisaabColors.forType(t)),
            label: Text(s.typeLabel(t),
                style: TextStyle(fontSize: 15, color: _type == t ? Colors.white : null)),
            onSelected: (_) => setState(() => _type = t),
          ),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatRupees(p.amountPaise!, devanagari: deva),
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: color)),
          if (_name != null && _type.needsCustomer)
            Row(children: [
              const Icon(Icons.person, size: 20),
              const SizedBox(width: 6),
              Text(_name!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ]),
          if (_note != null)
            Row(children: [
              const Icon(Icons.edit_note, size: 20),
              const SizedBox(width: 6),
              Flexible(child: Text(_note!, style: const TextStyle(fontSize: 18))),
            ]),
          if (_type.needsCustomer && (_name ?? '').isEmpty)
            Text(s.needCustomer, style: const TextStyle(fontSize: 15, color: HisaabColors.moneyOut)),
        ]),
      ),
      if (_type.hasPayMode) ...[
        const SizedBox(height: 12),
        PayModePicker(
          value: _mode ?? AppScope.of(context).lastPayMode,
          onChanged: (m) => setState(() => _mode = m),
        ),
      ],
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: _canSave ? _save : null,
              icon: const Icon(Icons.check, size: 26),
              label: Text(s.save, style: const TextStyle(fontSize: 20)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit),
            label: Text(s.edit, style: const TextStyle(fontSize: 17)),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        TextButton.icon(onPressed: _listen, icon: const Icon(Icons.mic), label: Text(s.tryAgain)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
      ]),
    ]);
  }
}

/// A red mic that gently pulses while listening.
class _PulsingMic extends StatefulWidget {
  const _PulsingMic();

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HisaabColors.moneyOut,
          boxShadow: [
            BoxShadow(
              color: HisaabColors.moneyOut.withAlpha((60 + 80 * _c.value).round()),
              blurRadius: 12 + 18 * _c.value,
              spreadRadius: 2 + 8 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
      child: const Icon(Icons.mic, color: Colors.white, size: 50),
    );
  }
}
