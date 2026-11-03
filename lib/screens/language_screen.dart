import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../widgets/logo.dart';
import '../widgets/motion.dart';

/// Pick a language: big tiles, each in its own script with its English name
/// underneath. Languages still waiting for a native-speaker check say "beta".
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, this.firstRun = false});
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final current = state.lang;
    final scheme = Theme.of(context).colorScheme;

    final tiles = [
      for (var i = 0; i < AppLang.values.length; i++)
        FadeSlideIn(
          key: ValueKey('lang-${AppLang.values[i].name}'),
          delayMs: i * 25,
          child: _LangTile(
            lang: AppLang.values[i],
            selected: AppLang.values[i] == current,
            onTap: () {
              state.setLang(AppLang.values[i]);
              if (!firstRun) Navigator.of(context).pop();
            },
          ),
        ),
    ];

    return Scaffold(
      appBar: firstRun ? null : AppBar(title: Text(state.s.language)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (firstRun) ...[
                  const SizedBox(height: 12),
                  const Center(child: HisaabLogo(size: 110)),
                  const SizedBox(height: 10),
                  Text('हिसाब  ·  Hisaab',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text('भाषा निवडा  ·  भाषा चुनें  ·  Choose your language',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, color: mutedText(context))),
                  const SizedBox(height: 24),
                ],
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 720 ? 3 : (c.maxWidth >= 440 ? 2 : 1);
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: cols == 1 ? 4.2 : 2.4,
                    children: tiles,
                  );
                }),
                if (!firstRun && current != null && current != AppLang.en) ...[
                  const SizedBox(height: 16),
                  Material(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: SwitchListTile(
                      value: state.devanagariDigits,
                      onChanged: state.setDevanagariDigits,
                      title: Text(state.s.localDigits, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({required this.lang, required this.selected, required this.onTap});
  final AppLang lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PressableScale(
      scale: 0.97,
      child: Material(
        color: selected ? HisaabColors.brand.withAlpha(26) : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? HisaabColors.brand : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Each name in its own reading direction (Urdu is RTL).
                      Text(lang.nativeName,
                          textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Flexible(
                          child: Text(lang.englishName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, color: mutedText(context))),
                        ),
                        if (lang.isBeta) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: mutedText(context)),
                            ),
                            child: Text(S(lang).beta,
                                style: TextStyle(fontSize: 11, color: mutedText(context))),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: motion(context, 200),
                  child: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    key: ValueKey(selected),
                    size: 28,
                    color: selected ? HisaabColors.brand : scheme.outlineVariant,
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
