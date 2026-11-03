import '../models/entry.dart';
import '../utils/format.dart' show toLatinDigits;

/// What we understood from one spoken sentence, e.g.
/// "Ram ko 200 udhaar"  ->  udhaar, ₹200, Ram.
class ParsedEntry {
  const ParsedEntry({
    required this.type,
    this.amountPaise,
    this.name,
    this.note,
    this.mode,
    this.typeFromWords = false,
  });

  final EntryType type;
  final int? amountPaise;

  /// Customer (udhaar / payment) or person paid (expense).
  final String? name;

  /// What it was for, e.g. "chai" in "chai 50 kharcha".
  final String? note;

  /// Set only when the person said "UPI", "PhonePe", "cash"...
  final PayMode? mode;

  /// False when no type word was heard and we guessed "sale".
  final bool typeFromWords;
}

/// Understands short Hindi / Marathi / English (Latin or Devanagari)
/// sentences a shopkeeper says. Anything unclear is left for the
/// shopkeeper to fix on the normal entry screen.
class EntryParser {
  const EntryParser._();

  // Type words, checked in this order (most specific first).
  static const _payment = [
    'jama', 'जमा', 'wapas', 'vapas', 'वापस', 'परत', 'parat', 'payment', 'paid back', 'received',
    'mila', 'mile', 'मिला', 'मिले', 'मिळाले', 'milale', 'de gaya', 'de gayi', 'दे गया', 'दे गई', 'दिले',
    'chukaya', 'चुकाया',
  ];
  static const _udhaar = [
    'udhaar', 'udhar', 'udhari', 'udhaari', 'उधार', 'उधारी', 'credit', 'baki', 'baaki', 'बाकी', 'बाक़ी',
    'khata', 'khaate', 'खाते', 'खाता',
  ];
  static const _expense = [
    'kharcha', 'kharch', 'kharche', 'खर्च', 'खर्चा', 'खर्चे', 'expense', 'spent', 'spend', 'kharida', 'kharidi',
    'खरीदा', 'खरीदी', 'खरेदी', 'pagaar', 'pagar', 'पगार', 'salary', 'तनख्वाह', 'bhada', 'bhaada', 'भाड़ा',
    'भाडा', 'rent',
  ];
  static const _sale = [
    'sale', 'sales', 'sold', 'sell', 'becha', 'bechi', 'बेचा', 'बेची', 'bikri', 'बिक्री', 'vikri', 'विक्री',
    'bika', 'बिका', 'galla', 'गल्ला', 'dhanda', 'धंधा', 'kamai', 'कमाई',
  ];
  static const _upi = ['upi', 'यूपीआई', 'phonepe', 'phone pe', 'फोनपे', 'gpay', 'google pay', 'paytm', 'पेटीएम', 'online', 'ऑनलाइन', 'qr'];
  static const _cash = ['cash', 'कैश', 'नकद', 'नगद', 'nakad', 'nagad', 'रोख', 'rokh'];

  // Little words that are not names.
  static const _fillers = {
    'ko', 'ne', 'ka', 'ki', 'ke', 'se', 'me', 'mein', 'mai', 'par', 'pe', 'aur', 'ek', 'hai', 'hain', 'tha',
    'kiya', 'kiye', 'kia', 'diya', 'diye', 'dia', 'gaya', 'gaye', 'liya', 'liye', 'karo', 'kar', 'likho',
    'aaj', 'abhi', 'the', 'a', 'an', 'to', 'from', 'for', 'of', 'by', 'given', 'gave', 'paid', 'rs', 'rupees',
    'rupee', 'rupaye', 'rupay', 'rupiya', 'rupaiya', 'ru', 'inr', 'add', 'entry', 'ji', 'wala', 'wale', 'and',
    'को', 'ने', 'का', 'की', 'के', 'से', 'में', 'पर', 'पे', 'और', 'है', 'हैं', 'था', 'किया', 'किए', 'किये', 'दिया',
    'दिए', 'दिये', 'गया', 'गए', 'लिया', 'लिए', 'करो', 'कर', 'लिखो', 'आज', 'अभी', 'रुपये', 'रुपए', 'रुपया', 'रुपै',
    'रु', 'जी', 'वाला', 'वाले', 'ला', 'ना', 'चा', 'ची', 'चे', 'केले', 'दिले', 'घेतले', 'झाली', 'झाले', 'आहे', 'आणि',
    'रुपये.', 'टाका', 'लिहा',
  };

  static const _thousand = ['hazar', 'hazaar', 'hajar', 'hajaar', 'हजार', 'हज़ार', 'thousand', 'k'];
  static const _hundred = ['sau', 'सौ', 'शे', 'hundred'];
  static const _lakh = ['lakh', 'lac', 'लाख'];

  static ParsedEntry parse(String spoken) {
    var text = ' ${toLatinDigits(spoken).toLowerCase()} ';
    // "1,500" -> "1500" first, then other punctuation becomes spaces.
    text = text.replaceAll(RegExp(r'(?<=\d),(?=\d)'), '');
    text = text.replaceAll('₹', ' ').replaceAll(RegExp(r'[,!?।.](?!\d)'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    bool hasWord(List<String> words) => words.any((w) => _containsWord(text, w));

    // "Mohan ne 500 diye" (Mohan gave 500) is a payment received.
    final gave = !hasWord(_sale) && hasWord(const ['ne', 'ने']) &&
        hasWord(const ['diye', 'diya', 'dia', 'दिए', 'दिये', 'दिया']);
    final type = hasWord(_payment) || gave
        ? EntryType.paymentReceived
        : hasWord(_udhaar)
            ? EntryType.udhaarGiven
            : hasWord(_expense)
                ? EntryType.expense
                : EntryType.sale;
    final fromWords = type != EntryType.sale || hasWord(_sale);
    final mode = hasWord(_upi) ? PayMode.upi : (hasWord(_cash) ? PayMode.cash : null);

    // Remove every keyword phrase so what's left is the name / note.
    var rest = text;
    for (final list in [_payment, _udhaar, _expense, _sale, _upi, _cash]) {
      for (final w in list) {
        rest = _removeWord(rest, w);
      }
    }

    // Amount: first number, with "2 hazar", "5 sau", "1.5 lakh" style multipliers.
    int? paise;
    final tokens = rest.trim().split(' ').where((t) => t.isNotEmpty).toList();
    final keep = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final number = RegExp(r'^(\d+(?:\.\d+)?)(k)?$').firstMatch(t);
      if (number != null && paise == null) {
        var value = double.parse(number.group(1)!);
        if (number.group(2) != null) value *= 1000;
        if (i + 1 < tokens.length) {
          final next = tokens[i + 1];
          final mult = _thousand.contains(next)
              ? 1000
              : _hundred.contains(next)
                  ? 100
                  : _lakh.contains(next)
                      ? 100000
                      : 1;
          if (mult != 1) {
            value *= mult;
            i++;
          }
        }
        final p = value.round() * 100; // whole rupees, like the amount box
        if (p > 0 && p <= 100000000000) paise = p;
        continue;
      }
      if (number != null) continue; // a second number: ignore
      if (_fillers.contains(t) || _thousand.contains(t) || _hundred.contains(t) || _lakh.contains(t)) continue;
      keep.add(t);
    }

    final words = keep.join(' ').trim();
    final pretty = words.isEmpty ? null : _titleCase(words);
    final isPerson = type == EntryType.udhaarGiven || type == EntryType.paymentReceived;
    return ParsedEntry(
      type: type,
      amountPaise: paise,
      name: isPerson ? pretty : null,
      note: isPerson ? null : pretty,
      mode: type.hasPayMode ? mode : null,
      typeFromWords: fromWords,
    );
  }

  static bool _containsWord(String text, String word) => _wordPattern(word).hasMatch(text);

  static String _removeWord(String text, String word) => text.replaceAll(_wordPattern(word), ' ');

  /// Whole word / phrase match that also works for Devanagari (no \b there).
  static RegExp _wordPattern(String word) =>
      RegExp('(?<=^|\\s)${RegExp.escape(word)}(?=\\s|\$)', unicode: true);

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
