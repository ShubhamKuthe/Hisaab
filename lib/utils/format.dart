const _latin = '0123456789';

/// Every Indian digit set the app knows (Devanagari, Bengali, Telugu, Tamil,
/// Gujarati, Kannada, Malayalam, Odia, Gurmukhi, Urdu, Meetei Mayek, Ol Chiki).
const allLocalDigitSets = [
  '०१२३४५६७८९', '০১২৩৪৫৬৭৮৯', '౦౧౨౩౪౫౬౭౮౯', '௦௧௨௩௪௫௬௭௮௯', '૦૧૨૩૪૫૬૭૮૯',
  '೦೧೨೩೪೫೬೭೮೯', '൦൧൨൩൪൫൬൭൮൯', '୦୧୨୩୪୫୬୭୮୯', '੦੧੨੩੪੫੬੭੮੯', '۰۱۲۳۴۵۶۷۸۹',
  '꯰꯱꯲꯳꯴꯵꯶꯷꯸꯹', // Meetei Mayek (Manipuri)
  '᱐᱑᱒᱓᱔᱕᱖᱗᱘᱙', // Ol Chiki (Santali)
];

/// The digits used when "local digits" is on. Set from the chosen language
/// (see AppState); Devanagari by default.
String localDigitSet = '०१२३४५६७८९';

/// Lets number boxes accept 0-9 and every Indian digit set.
final digitInputPattern = RegExp('[0-9${allLocalDigitSets.join()}]');
final decimalInputPattern = RegExp('[0-9.${allLocalDigitSets.join()}]');

/// Swaps 0-9 for the current language's own digits when asked.
String toDigits(String s, bool local) {
  if (!local) return s;
  final out = StringBuffer();
  for (final ch in s.split('')) {
    final i = _latin.indexOf(ch);
    out.write(i >= 0 ? localDigitSet[i] : ch);
  }
  return out.toString();
}

/// Turns any Indian digits back into 0-9 (for typed input).
String toLatinDigits(String s) {
  final out = StringBuffer();
  for (final ch in s.split('')) {
    var mapped = ch;
    for (final set in allLocalDigitSets) {
      final i = set.indexOf(ch);
      if (i >= 0) {
        mapped = _latin[i];
        break;
      }
    }
    out.write(mapped);
  }
  return out.toString();
}

/// Indian grouping: 1234567 -> 12,34,567
String groupIndian(int n) {
  final s = n.abs().toString();
  if (s.length <= 3) return n < 0 ? '-$s' : s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  final grouped = '${parts.join(',')},$last3';
  return n < 0 ? '-$grouped' : grouped;
}

/// 150050 paise -> ₹1,500.50 ; 150000 -> ₹1,500
String formatRupees(int paise, {bool devanagari = false}) {
  final abs = paise.abs();
  final rupees = abs ~/ 100;
  final p = abs % 100;
  var s = groupIndian(rupees);
  if (p != 0) s += '.${p.toString().padLeft(2, '0')}';
  return toDigits('${paise < 0 ? '-' : ''}₹$s', devanagari);
}

String formatTime(DateTime t, {bool devanagari = false}) => toDigits(
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
    devanagari);

String formatDate(DateTime d, {bool devanagari = false}) =>
    toDigits('${d.day}/${d.month}/${d.year}', devanagari);

/// Parses whole rupees typed by the user ("500" or "५००") into paise.
/// Returns null when empty, zero or unreasonably large.
int? parseRupeesToPaise(String input) {
  final digits = toLatinDigits(input.trim()).replaceAll(',', '');
  final rupees = int.tryParse(digits);
  if (rupees == null || rupees <= 0 || rupees > 1000000000) return null;
  return rupees * 100;
}

/// Quantity typed on a bill ("2", "0.5", "१.५"). Empty means 1.
/// Returns null if it isn't a sensible number.
double? parseQty(String input) {
  final t = toLatinDigits(input.trim());
  if (t.isEmpty) return 1;
  final v = double.tryParse(t);
  if (v == null || v <= 0 || v > 100000) return null;
  return v;
}

/// Item price typed on a bill ("45" or "12.50") into paise.
int? parsePricePaise(String input) {
  final v = double.tryParse(toLatinDigits(input.trim()).replaceAll(',', ''));
  if (v == null || v <= 0 || v > 10000000) return null;
  return (v * 100).round();
}

/// 2.0 -> "2", 0.5 -> "0.5", 1.25 -> "1.25"
String formatQty(double q, {bool devanagari = false}) {
  final s = q == q.truncateToDouble()
      ? q.toInt().toString()
      : q.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return toDigits(s, devanagari);
}

/// Paise back into what you'd type in a price box: 4500 -> "45", 1250 -> "12.50"
String paiseToInput(int paise) =>
    paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);
