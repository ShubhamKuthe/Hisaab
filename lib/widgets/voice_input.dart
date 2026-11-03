import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app.dart';
import '../l10n/strings.dart';

/// Talk instead of typing. Uses the speech recogniser built into
/// Windows / Android — Hisaab itself sends nothing anywhere.
class Voice {
  Voice._();

  static final _stt = SpeechToText();
  static bool _ready = false;
  static List<LocaleName> _locales = const [];

  /// Which mic button is listening right now (null = none).
  static final active = ValueNotifier<Object?>(null);

  static Future<bool> _init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onStatus: (st) {
          if (st == 'done' || st == 'notListening') active.value = null;
        },
        onError: (_) => active.value = null,
      );
      if (_ready) _locales = await _stt.locales();
    } catch (_) {
      _ready = false; // try again next tap (e.g. after allowing the mic)
    }
    return _ready;
  }

  /// Speech locale for the app language, with close fallbacks.
  static String? _localeFor(AppLang lang) {
    const own = {
      AppLang.mr: 'mr-IN', AppLang.hi: 'hi-IN', AppLang.en: 'en-IN', AppLang.bn: 'bn-IN',
      AppLang.te: 'te-IN', AppLang.ta: 'ta-IN', AppLang.gu: 'gu-IN', AppLang.kn: 'kn-IN',
      AppLang.ml: 'ml-IN', AppLang.od: 'or-IN', AppLang.pa: 'pa-IN', AppLang.ur: 'ur-IN',
      AppLang.asm: 'as-IN', AppLang.kok: 'kok-IN', AppLang.ne: 'ne-NP', AppLang.mai: 'mai-IN',
      AppLang.doi: 'doi-IN', AppLang.brx: 'brx-IN', AppLang.sa: 'sa-IN', AppLang.ks: 'ks-IN',
      AppLang.sd: 'sd-IN', AppLang.mni: 'mni-IN', AppLang.sat: 'sat-IN', AppLang.tcy: 'tcy-IN',
    };
    const near = {
      AppLang.tcy: 'kn-IN', AppLang.kok: 'mr-IN', AppLang.asm: 'bn-IN', AppLang.ks: 'ur-IN',
      AppLang.sd: 'ur-IN', AppLang.mai: 'hi-IN', AppLang.doi: 'hi-IN', AppLang.brx: 'hi-IN',
      AppLang.sa: 'hi-IN', AppLang.ne: 'hi-IN', AppLang.sat: 'hi-IN', AppLang.mni: 'bn-IN',
    };
    String norm(String id) => id.replaceAll('_', '-').toLowerCase();
    final ids = _locales.map((l) => l.localeId).toList();
    String? find(String want) {
      final w = want.toLowerCase();
      for (final id in ids) {
        if (norm(id) == w) return id;
      }
      final langOnly = w.split('-').first;
      for (final id in ids) {
        if (norm(id).split('-').first == langOnly) return id;
      }
      return null;
    }

    for (final want in [own[lang], near[lang], 'hi-IN', 'en-IN']) {
      if (want == null) continue;
      final hit = find(want);
      if (hit != null) return hit;
    }
    return null; // the device's own default
  }

  static Future<bool> start(Object owner, AppLang lang, void Function(String words) onWords,
      {void Function(String words)? onFinal}) async {
    if (!await _init()) return false;
    try {
      if (_stt.isListening) await _stt.stop();
      active.value = owner;
      await _stt.listen(
        localeId: _localeFor(lang),
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (r) {
          if (active.value != owner) return;
          onWords(r.recognizedWords);
          if (r.finalResult) {
            active.value = null;
            onFinal?.call(r.recognizedWords);
          }
        },
      );
      return true;
    } catch (_) {
      active.value = null;
      return false;
    }
  }

  static Future<void> stop() async {
    active.value = null;
    try {
      await _stt.stop();
    } catch (_) {}
  }
}

/// 🎤 button for the end of a text box. Tap, speak, the words appear in the box.
/// Tap again (or stop talking) to finish.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.controller,
    this.onChanged,
    this.append = false,
    this.names = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  /// Add to what is already typed (notes) instead of replacing it (names).
  final bool append;

  /// Capitalise each word, for people's names ("ram kumar" -> "Ram Kumar").
  final bool names;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  @override
  void dispose() {
    if (Voice.active.value == this) Voice.stop();
    super.dispose();
  }

  String _tidy(String w) {
    if (!widget.names) return w;
    return w
        .split(' ')
        .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  Future<void> _toggle() async {
    if (Voice.active.value == this) {
      await Voice.stop();
      return;
    }
    final state = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final old = widget.controller.text.trim();
    final base = widget.append && old.isNotEmpty ? '$old ' : '';
    final ok = await Voice.start(this, state.lang ?? AppLang.mr, (words) {
      if (!mounted) return;
      final t = base + _tidy(words);
      widget.controller.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
      widget.onChanged?.call(t);
    });
    if (ok && mounted) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: Row(children: [
          const Icon(Icons.mic, color: Colors.white),
          const SizedBox(width: 10),
          Text(state.s.listening, style: const TextStyle(fontSize: 17)),
        ]),
      ));
    }
    if (!ok && mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(state.s.voiceUnavailable, style: const TextStyle(fontSize: 16)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    return ValueListenableBuilder<Object?>(
      valueListenable: Voice.active,
      builder: (context, owner, _) {
        final on = owner == this;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: on ? s.listening : s.speak,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? HisaabColors.moneyOut : HisaabColors.brand.withAlpha(30),
              ),
              child: IconButton(
                onPressed: _toggle,
                icon: Icon(on ? Icons.mic : Icons.mic_none,
                    color: on ? Colors.white : HisaabColors.brand, size: 26),
              ),
            ),
          ),
        );
      },
    );
  }
}
