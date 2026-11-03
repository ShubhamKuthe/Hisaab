import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/format.dart';

/// Small, cheap animations built only from Flutter's own widgets: no
/// packages, no blur, no shaders - smooth even on low-end Android phones.
/// Everything turns off when the phone's "remove animations" setting is on.

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

Duration motion(BuildContext context, int ms) =>
    reduceMotion(context) ? Duration.zero : Duration(milliseconds: ms);

/// Page change: a quick fade with a tiny upward slide.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// Fades and slides its child in once, when it first appears.
/// [delayMs] staggers lists so rows arrive one after another.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.durationMs = 320,
    this.offsetY = 14,
  });

  final Widget child;
  final int delayMs;
  final int durationMs;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final total = delayMs + durationMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * offsetY), child: child),
      ),
    );
  }
}

/// A rupee amount that counts up/down smoothly when it changes.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney({
    super.key,
    required this.paise,
    required this.style,
    this.devanagari = false,
  });

  final int paise;
  final TextStyle style;
  final bool devanagari;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: paise.toDouble()), // counts up on first show
      duration: motion(context, 550),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text(formatRupees(v.round(), devanagari: devanagari), style: style),
    );
  }
}

/// Shrinks a little while pressed, like a real button.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.scale = 0.96});
  final Widget child;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: motion(context, 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Shakes its child sideways each time [trigger] changes (e.g. wrong PIN).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});
  final Object? trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != null && widget.trigger != old.trigger && !reduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
