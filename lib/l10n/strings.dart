import 'package:flutter/material.dart' show ThemeMode;

import '../models/entry.dart';
import 'lang/mr.dart';
import 'lang/hi.dart';
import 'lang/en.dart';
import 'lang/bn.dart';
import 'lang/te.dart';
import 'lang/ta.dart';
import 'lang/gu.dart';
import 'lang/kn.dart';
import 'lang/ml.dart';
import 'lang/od.dart';
import 'lang/pa.dart';
import 'lang/ur.dart';
import 'lang/asm.dart';
import 'lang/kok.dart';
import 'lang/ne.dart';
import 'lang/mai.dart';
import 'lang/doi.dart';
import 'lang/brx.dart';
import 'lang/sa.dart';
import 'lang/ks.dart';
import 'lang/sd.dart';
import 'lang/mni.dart';
import 'lang/sat.dart';
import 'lang/tcy.dart';

/// Every language Hisaab speaks: all 22 official languages of India, plus
/// English and Tulu. Saved by name, so never rename these.
enum AppLang { mr, hi, en, bn, te, ta, gu, kn, ml, od, pa, ur, asm, kok, ne, mai, doi, brx, sa, ks, sd, mni, sat, tcy }

extension AppLangInfo on AppLang {
  /// The language's own name, shown on the language screen.
  String get nativeName => switch (this) {
        AppLang.mr => 'मराठी',
        AppLang.hi => 'हिंदी',
        AppLang.en => 'English',
        AppLang.bn => 'বাংলা',
        AppLang.te => 'తెలుగు',
        AppLang.ta => 'தமிழ்',
        AppLang.gu => 'ગુજરાતી',
        AppLang.kn => 'ಕನ್ನಡ',
        AppLang.ml => 'മലയാളം',
        AppLang.od => 'ଓଡ଼ିଆ',
        AppLang.pa => 'ਪੰਜਾਬੀ',
        AppLang.ur => 'اردو',
        AppLang.asm => 'অসমীয়া',
        AppLang.kok => 'कोंकणी',
        AppLang.ne => 'नेपाली',
        AppLang.mai => 'मैथिली',
        AppLang.doi => 'डोगरी',
        AppLang.brx => 'बर\'',
        AppLang.sa => 'संस्कृतम्',
        AppLang.ks => 'کٲشُر',
        AppLang.sd => 'سنڌي',
        AppLang.mni => 'ꯃꯤꯇꯩꯂꯣꯟ',
        AppLang.sat => 'ᱥᱟᱱᱛᱟᱲᱤ',
        AppLang.tcy => 'ತುಳು',
      };

  /// English name, for people who can't read the script yet.
  String get englishName => switch (this) {
        AppLang.mr => 'Marathi',
        AppLang.hi => 'Hindi',
        AppLang.en => 'English',
        AppLang.bn => 'Bengali',
        AppLang.te => 'Telugu',
        AppLang.ta => 'Tamil',
        AppLang.gu => 'Gujarati',
        AppLang.kn => 'Kannada',
        AppLang.ml => 'Malayalam',
        AppLang.od => 'Odia',
        AppLang.pa => 'Punjabi',
        AppLang.ur => 'Urdu',
        AppLang.asm => 'Assamese',
        AppLang.kok => 'Konkani',
        AppLang.ne => 'Nepali',
        AppLang.mai => 'Maithili',
        AppLang.doi => 'Dogri',
        AppLang.brx => 'Bodo',
        AppLang.sa => 'Sanskrit',
        AppLang.ks => 'Kashmiri',
        AppLang.sd => 'Sindhi',
        AppLang.mni => 'Manipuri',
        AppLang.sat => 'Santali',
        AppLang.tcy => 'Tulu',
      };

  /// 0-9 in this language's own script.
  String get digits => switch (this) {
        AppLang.mr => '०१२३४५६७८९',
        AppLang.hi => '०१२३४५६७८९',
        AppLang.en => '0123456789',
        AppLang.bn => '০১২৩৪৫৬৭৮৯',
        AppLang.te => '౦౧౨౩౪౫౬౭౮౯',
        AppLang.ta => '௦௧௨௩௪௫௬௭௮௯',
        AppLang.gu => '૦૧૨૩૪૫૬૭૮૯',
        AppLang.kn => '೦೧೨೩೪೫೬೭೮೯',
        AppLang.ml => '൦൧൨൩൪൫൬൭൮൯',
        AppLang.od => '୦୧୨୩୪୫୬୭୮୯',
        AppLang.pa => '੦੧੨੩੪੫੬੭੮੯',
        AppLang.ur => '۰۱۲۳۴۵۶۷۸۹',
        AppLang.asm => '০১২৩৪৫৬৭৮৯',
        AppLang.kok => '०१२३४५६७८९',
        AppLang.ne => '०१२३४५६७८९',
        AppLang.mai => '०१२३४५६७८९',
        AppLang.doi => '०१२३४५६७८९',
        AppLang.brx => '०१२३४५६७८९',
        AppLang.sa => '०१२३४५६७८९',
        AppLang.ks => '۰۱۲۳۴۵۶۷۸۹',
        AppLang.sd => '۰۱۲۳۴۵۶۷۸۹',
        AppLang.mni => '꯰꯱꯲꯳꯴꯵꯶꯷꯸꯹',
        AppLang.sat => '᱐᱑᱒᱓᱔᱕᱖᱗᱘᱙',
        AppLang.tcy => '೦೧೨೩೪೫೬೭೮೯',
      };

  /// Urdu, Kashmiri and Sindhi are written right to left.
  bool get isRtl => this == AppLang.ur || this == AppLang.ks || this == AppLang.sd;

  /// Marathi, Hindi and English are checked; the rest are drafts that a
  /// native speaker should review, so the app labels them "beta".
  bool get isBeta => !(this == AppLang.mr || this == AppLang.hi || this == AppLang.en);

  /// Only some lines translated so far; the rest come from [fallback].
  bool get isPartial => const {AppLang.mai, AppLang.doi, AppLang.brx, AppLang.sa, AppLang.ks, AppLang.sd, AppLang.mni, AppLang.sat, AppLang.tcy}.contains(this);

  /// Where to look when a line isn't translated: the closest language its
  /// readers know (Konkani -> Marathi, Assamese -> Bengali, Kashmiri/Sindhi ->
  /// Urdu, Tulu -> Kannada, Hindi-belt languages -> Hindi), then English.
  AppLang? get fallback => switch (this) {
        AppLang.en => null,
        AppLang.tcy => AppLang.kn,
        AppLang.asm => AppLang.bn,
        AppLang.kok => AppLang.mr,
        AppLang.mai => AppLang.hi,
        AppLang.doi => AppLang.hi,
        AppLang.brx => AppLang.hi,
        AppLang.sa => AppLang.hi,
        AppLang.ne => AppLang.hi,
        AppLang.sat => AppLang.hi,
        AppLang.ks => AppLang.ur,
        AppLang.sd => AppLang.ur,
        _ => AppLang.en,
      };
}

const Map<AppLang, Map<String, String>> _strings = {
  AppLang.mr: mrStrings,
  AppLang.hi: hiStrings,
  AppLang.en: enStrings,
  AppLang.bn: bnStrings,
  AppLang.te: teStrings,
  AppLang.ta: taStrings,
  AppLang.gu: guStrings,
  AppLang.kn: knStrings,
  AppLang.ml: mlStrings,
  AppLang.od: odStrings,
  AppLang.pa: paStrings,
  AppLang.ur: urStrings,
  AppLang.asm: asmStrings,
  AppLang.kok: kokStrings,
  AppLang.ne: neStrings,
  AppLang.mai: maiStrings,
  AppLang.doi: doiStrings,
  AppLang.brx: brxStrings,
  AppLang.sa: saStrings,
  AppLang.ks: ksStrings,
  AppLang.sd: sdStrings,
  AppLang.mni: mniStrings,
  AppLang.sat: satStrings,
  AppLang.tcy: tcyStrings,
};

/// All on-screen text. Each language lives in its own file under lang/.
/// Usage: `S(AppLang.mr).sale`
class S {
  const S(this.lang);
  final AppLang lang;

  /// Looks the line up in this language, then its fallback (Tulu -> Kannada,
  /// everything -> English), so a missing translation never shows blank.
  String _t(String key) {
    AppLang? l = lang;
    while (l != null) {
      final v = _strings[l]![key];
      if (v != null) return v;
      l = l.fallback;
    }
    return key;
  }

  /// True if this language has its own text for [key] (used by tests).
  static bool has(AppLang l, String key) => _strings[l]!.containsKey(key);
  static Iterable<String> get keys => _strings[AppLang.en]!.keys;

  static String languageName(AppLang l) => l.nativeName;
  static String languageSample(AppLang l) {
    final s = S(l);
    return '${s.sale} · ${s.expense} · ${s.billNo}';
  }

  String get appName => _t('appName');
  String get tagline => _t('tagline');
  String get language => _t('language');
  String get sale => _t('sale');
  String get expense => _t('expense');
  String get udhaarGiven => _t('udhaarGiven');
  String get paymentReceived => _t('paymentReceived');
  String get today => _t('today');
  String get moneyIn => _t('moneyIn');
  String get moneyOut => _t('moneyOut');
  String get netToday => _t('netToday');
  String get totalDue => _t('totalDue');
  String get whoOwes => _t('whoOwes');
  String get todaysEntries => _t('todaysEntries');
  String get noEntries => _t('noEntries');
  String get amount => _t('amount');
  String get customerName => _t('customerName');
  String get spentBy => _t('spentBy');
  String get paidTo => _t('paidTo');
  String get searchPaidTo => _t('searchPaidTo');
  String get totalPaid => _t('totalPaid');
  String get noPaidTo => _t('noPaidTo');
  String get changePin => _t('changePin');
  String get currentPin => _t('currentPin');
  String get pinChanged => _t('pinChanged');
  String get oldCodeInvalid => _t('oldCodeInvalid');
  String get speak => _t('speak');
  String get listening => _t('listening');
  String get voiceUnavailable => _t('voiceUnavailable');
  String get moneyWithMe => _t('moneyWithMe');
  String get moneyWithMeHint => _t('moneyWithMeHint');
  String get tapToSee => _t('tapToSee');
  String get hide => _t('hide');
  String get autoBackup => _t('autoBackup');
  String get autoBackupDone => _t('autoBackupDone');
  String get badUpi => _t('badUpi');
  String get bestDay => _t('bestDay');
  String get bills => _t('bills');
  String get cash => _t('cash');
  String get cashInDrawer => _t('cashInDrawer');
  String get closeDay => _t('closeDay');
  String get copied => _t('copied');
  String get copy => _t('copy');
  String get customerPhone => _t('customerPhone');
  String get dailyAverage => _t('dailyAverage');
  String get daySummary => _t('daySummary');
  String get deleted => _t('deleted');
  String get didntCatch => _t('didntCatch');
  String get editEntry => _t('editEntry');
  String get entriesCount => _t('entriesCount');
  String get heard => _t('heard');
  String get last7Days => _t('last7Days');
  String get lastMonth => _t('lastMonth');
  String get noDataPeriod => _t('noDataPeriod');
  String get other => _t('other');
  String get payMode => _t('payMode');
  String get reports => _t('reports');
  String get scanToPay => _t('scanToPay');
  String get sendReminder => _t('sendReminder');
  String get shareWhatsapp => _t('shareWhatsapp');
  String get shopUpi => _t('shopUpi');
  String get speakEntry => _t('speakEntry');
  String get speakExamples => _t('speakExamples');
  String get thisMonth => _t('thisMonth');
  String get topExpenses => _t('topExpenses');
  String get tryAgain => _t('tryAgain');
  String get undo => _t('undo');
  String get updated => _t('updated');
  String get upi => _t('upi');
  String get whatsappFailed => _t('whatsappFailed');
  String payByUpi(String upi) => _t('payByUpi').replaceAll('{upi}', upi);
  String reminderMsg(String name, String amount) =>
      _t('reminderMsg').replaceAll('{name}', name).replaceAll('{amount}', amount);
  String get optional => _t('optional');
  String get note => _t('note');
  String get save => _t('save');
  String get cancel => _t('cancel');
  String get enterAmount => _t('enterAmount');
  String get needCustomer => _t('needCustomer');
  String get saved => _t('saved');
  String get escHint => _t('escHint');
  String get delete => _t('delete');
  String get deleteConfirm => _t('deleteConfirm');
  String get yes => _t('yes');
  String get no => _t('no');
  String get customers => _t('customers');
  String get due => _t('due');
  String get settled => _t('settled');
  String get advance => _t('advance');
  String get search => _t('search');
  String get noCustomers => _t('noCustomers');
  String get saveFailed => _t('saveFailed');
  String get history => _t('history');
  String get exportDone => _t('exportDone');
  String get exportFailed => _t('exportFailed');
  String get openFolder => _t('openFolder');
  String get colDate => _t('colDate');
  String get colTime => _t('colTime');
  String get colType => _t('colType');
  String get colAmount => _t('colAmount');
  String get colDue => _t('colDue');
  String get colNet => _t('colNet');
  String get sheetCustomers => _t('sheetCustomers');
  String get sheetDaily => _t('sheetDaily');
  String get backupNow => _t('backupNow');
  String get backupExplain => _t('backupExplain');
  String get chooseBackupFolder => _t('chooseBackupFolder');
  String get backupDone => _t('backupDone');
  String get backupFailed => _t('backupFailed');
  String get sameComputerWarning => _t('sameComputerWarning');
  String get restore => _t('restore');
  String get notABackup => _t('notABackup');
  String get exportForCa => _t('exportForCa');
  String get setPinTitle => _t('setPinTitle');
  String get setPinHint => _t('setPinHint');
  String get confirmPin => _t('confirmPin');
  String get pinMismatch => _t('pinMismatch');
  String get enterPin => _t('enterPin');
  String get wrongPin => _t('wrongPin');
  String get forgotPin => _t('forgotPin');
  String get recoveryTitle => _t('recoveryTitle');
  String get recoveryExplain => _t('recoveryExplain');
  String get iWroteIt => _t('iWroteIt');
  String get enterRecovery => _t('enterRecovery');
  String get wrongRecovery => _t('wrongRecovery');
  String get newPinTitle => _t('newPinTitle');
  String get lock => _t('lock');
  String get back => _t('back');
  String get simpleMode => _t('simpleMode');
  String get advancedMode => _t('advancedMode');
  String get modeHint => _t('modeHint');
  String get makeBill => _t('makeBill');
  String get shopName => _t('shopName');
  String get shopPhone => _t('shopPhone');
  String get item => _t('item');
  String get qty => _t('qty');
  String get price => _t('price');
  String get addItem => _t('addItem');
  String get total => _t('total');
  String get billNo => _t('billNo');
  String get payLater => _t('payLater');
  String get savePrint => _t('savePrint');
  String get saveImage => _t('saveImage');
  String get print => _t('print');
  String get image => _t('image');
  String get thankYou => _t('thankYou');
  String get billSaved => _t('billSaved');
  String get needItems => _t('needItems');
  String get billImageSaved => _t('billImageSaved');
  String get recentItems => _t('recentItems');
  String get unpaid => _t('unpaid');
  String get searchCustomer => _t('searchCustomer');
  String get noMatch => _t('noMatch');
  String get edit => _t('edit');
  String get done => _t('done');

  String typeLabel(EntryType t) => switch (t) {
        EntryType.sale => sale,
        EntryType.expense => expense,
        EntryType.udhaarGiven => udhaarGiven,
        EntryType.paymentReceived => paymentReceived,
      };

  String lastBackup(int? days) {
    final when = switch (days) {
      null => _t('never'),
      0 => _t('todayLower'),
      1 => _t('yesterday'),
      _ => _t('daysAgo').replaceAll('{n}', '$days'),
    };
    return '${_t('lastBackupLabel')}: $when';
  }

  String restored(int n) => _t('restored').replaceAll('{n}', '$n');
  String tryAgainIn(int seconds) => _t('tryAgainIn').replaceAll('{n}', '$seconds');

  /// "Local digits (१२३)" in each language, showing its own digits.
  String get localDigits => _t('localDigits').replaceAll('{d}', lang.digits.substring(1, 4));
  String get beta => _t('beta');

  String themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.light => _t('themeLight'),
        ThemeMode.dark => _t('themeDark'),
        ThemeMode.system => _t('themeSystem'),
      };
}
