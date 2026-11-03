import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'models/entry.dart';
import 'screens/home_screen.dart';
import 'screens/language_screen.dart';
import 'screens/pin_screens.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/motion.dart';

/// Gives every screen access to [AppState] and rebuilds them when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Colours shopkeepers read at a glance - tiranga saffron & green first.
class HisaabColors {
  static const brand = Tiranga.saffronDeep; // saffron
  static const moneyIn = Color(0xFF1E9A2A); // India green
  static const moneyOut = Color(0xFFE53935); // kumkum red
  static const udhaar = Color(0xFFD81B60); // rani pink
  static const bill = Color(0xFF8E24AA); // jamun purple
  static const payment = Color(0xFF00897B); // peacock teal

  static Color forType(EntryType t) => switch (t) {
        EntryType.sale => moneyIn,
        EntryType.paymentReceived => moneyIn,
        EntryType.expense => moneyOut,
        EntryType.udhaarGiven => udhaar,
      };

  static IconData iconFor(EntryType t) => switch (t) {
        EntryType.sale => Icons.point_of_sale,
        EntryType.expense => Icons.receipt_long,
        EntryType.udhaarGiven => Icons.handshake,
        EntryType.paymentReceived => Icons.payments,
      };
}

final _lightTheme = buildHisaabTheme(Brightness.light);
final _darkTheme = buildHisaabTheme(Brightness.dark);

class HisaabApp extends StatelessWidget {
  const HisaabApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Hisaab',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: state.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 300),
          themeAnimationCurve: Curves.easeInOut,
          // Urdu reads right to left: flip the whole layout for it.
          builder: (context, child) => Directionality(
            textDirection: (state.lang?.isRtl ?? false) ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
          home: const RootGate(),
        ),
      ),
    );
  }
}

/// Secondary text colour that works in light and dark mode.
Color mutedText(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;

/// First run: pick a language, then set a PIN.
/// Every start after that: enter the PIN, then the book opens.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final (String stage, Widget screen) = !state.loaded
        ? ('loading', const Scaffold(body: Center(child: CircularProgressIndicator())))
        : state.lang == null
            ? ('language', const LanguageScreen(firstRun: true))
            : !state.hasPin
                ? ('setPin', const PinSetupScreen())
                : !state.unlocked
                    ? ('locked', const PinUnlockScreen())
                    : ('home', const HomeScreen());
    // Cross-fade between start-up steps (e.g. PIN screen -> book).
    return AnimatedSwitcher(
      duration: motion(context, 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(key: ValueKey(stage), child: screen),
    );
  }
}
