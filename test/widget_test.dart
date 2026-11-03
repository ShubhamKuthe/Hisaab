import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/export/hisaab_export.dart';
import 'package:hisaab/export/xlsx_writer.dart';
import 'package:hisaab/data/hisaab_data.dart';
import 'package:hisaab/data/store.dart';
import 'package:hisaab/l10n/strings.dart';
import 'package:hisaab/models/entry.dart';
import 'package:hisaab/state/app_state.dart';
import 'package:hisaab/utils/format.dart';
import 'package:hisaab/utils/whatsapp.dart';
import 'package:hisaab/voice/entry_parser.dart';

void main() {
  group('format', () {
    test('Indian grouping', () {
      expect(groupIndian(0), '0');
      expect(groupIndian(999), '999');
      expect(groupIndian(1000), '1,000');
      expect(groupIndian(100000), '1,00,000');
      expect(groupIndian(12345678), '1,23,45,678');
    });

    test('rupees and Devanagari digits', () {
      expect(formatRupees(150000), '₹1,500');
      expect(formatRupees(150050), '₹1,500.50');
      expect(formatRupees(-20000), '-₹200');
      localDigitSet = AppLang.hi.digits;
      expect(formatRupees(25000, devanagari: true), '₹२५०');
    });

    test('parsing typed amounts', () {
      expect(parseRupeesToPaise('500'), 50000);
      expect(parseRupeesToPaise('५००'), 50000);
      expect(parseRupeesToPaise(''), isNull);
      expect(parseRupeesToPaise('0'), isNull);
    });
  });

  group('AppState', () {
    late DateTime now;
    late AppState state;

    setUp(() async {
      now = DateTime(2026, 11, 2, 10, 0);
      state = AppState(MemoryStore(), clock: () => now);
      await state.init();
    });

    test('today summary adds up money in, out and udhaar', () {
      state.addEntry(type: EntryType.sale, amountPaise: 100000);
      state.addEntry(type: EntryType.expense, amountPaise: 30000);
      state.addEntry(type: EntryType.udhaarGiven, amountPaise: 20000, customer: 'Ramesh');
      state.addEntry(type: EntryType.paymentReceived, amountPaise: 5000, customer: 'Ramesh');
      final t = state.today();
      expect(t.moneyIn, 105000);
      expect(t.moneyOut, 30000);
      expect(t.udhaarGiven, 20000);
      expect(t.net, 75000);
    });

    test('money with me counts every day: money in minus expenses, not udhaar', () {
      now = DateTime(2026, 10, 30, 12);
      state.addEntry(type: EntryType.sale, amountPaise: 100000);
      state.addEntry(type: EntryType.udhaarGiven, amountPaise: 40000, customer: 'Ramesh');
      now = DateTime(2026, 11, 2, 10);
      state.addEntry(type: EntryType.expense, amountPaise: 25000);
      state.addEntry(type: EntryType.paymentReceived, amountPaise: 10000, customer: 'Ramesh');
      expect(state.moneyWithMe(), 85000);
    });

    test('yesterday is not counted in today', () {
      now = DateTime(2026, 11, 1, 18);
      state.addEntry(type: EntryType.sale, amountPaise: 99900);
      now = DateTime(2026, 11, 2, 9);
      expect(state.today().moneyIn, 0);
      expect(state.todayEntries(), isEmpty);
    });

    test('balances group names ignoring case and spaces', () {
      state.addEntry(type: EntryType.udhaarGiven, amountPaise: 50000, customer: 'ramesh  patil');
      state.addEntry(type: EntryType.udhaarGiven, amountPaise: 10000, customer: 'Ramesh Patil');
      state.addEntry(type: EntryType.paymentReceived, amountPaise: 20000, customer: ' RAMESH PATIL ');
      state.addEntry(type: EntryType.udhaarGiven, amountPaise: 5000, customer: 'Sunita');
      final b = state.balances();
      expect(b.length, 2);
      expect(b.first.duePaise, 40000);
      expect(state.totalDue(), 45000);
      expect(state.dueFor('ramesh patil'), 40000);
    });

    test('advance payment shows as negative and is not in total due', () {
      state.addEntry(type: EntryType.paymentReceived, amountPaise: 10000, customer: 'Amit');
      expect(state.dueFor('Amit'), -10000);
      expect(state.totalDue(), 0);
    });

    test('udhaar without a customer is rejected', () {
      expect(() => state.addEntry(type: EntryType.udhaarGiven, amountPaise: 100),
          throwsArgumentError);
      expect(() => state.addEntry(type: EntryType.sale, amountPaise: 0),
          throwsArgumentError);
    });

    test('delete removes the entry', () {
      final e = state.addEntry(type: EntryType.sale, amountPaise: 100);
      state.deleteEntry(e.id);
      expect(state.entries, isEmpty);
    });
  });

  group('JsonFileStore', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('hisaab_test'));
    tearDown(() async => dir.delete(recursive: true));

    test('saves and loads the book', () async {
      final store = JsonFileStore(directory: () async => dir);
      final state = AppState(store);
      await state.init();
      state.setLang(AppLang.mr);
      state.addEntry(type: EntryType.udhaarGiven, amountPaise: 25000, customer: 'रमेश');
      await state.flush();

      final again = AppState(JsonFileStore(directory: () async => dir));
      await again.init();
      expect(again.lang, AppLang.mr);
      expect(again.dueFor('रमेश'), 25000);
    });

    test('a damaged file falls back to the daily backup', () async {
      final store = JsonFileStore(directory: () async => dir);
      await store.save(HisaabData(lang: AppLang.hi));
      final sep = Platform.pathSeparator;
      await File('${dir.path}${sep}hisaab_data.json').writeAsString('{broken');
      final loaded = await store.load();
      expect(loaded.lang, AppLang.hi);
    });

    test('one bad entry does not lose the others', () {
      final data = HisaabData.fromJson({
        'entries': [
          {'id': 'a', 'type': 'sale', 'amount': 100, 'at': '2026-11-02T10:00:00.000'},
          {'id': 'b', 'type': 'nonsense'},
        ],
      });
      expect(data.entries.length, 1);
    });
  });

  group('Excel export', () {
    test('column letters', () {
      expect(columnName(0), 'A');
      expect(columnName(25), 'Z');
      expect(columnName(26), 'AA');
    });

    test('builds a valid xlsx with all three sheets in Marathi', () async {
      final state = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 2, 10));
      await state.init();
      state.addEntry(type: EntryType.sale, amountPaise: 150050);
      state.addEntry(type: EntryType.udhaarGiven, amountPaise: 20000, customer: 'रमेश & Co');

      final bytes = buildHisaabXlsx(
        entries: state.entries,
        balances: state.balances(),
        s: const S(AppLang.mr),
      );
      expect(bytes.sublist(0, 2), [0x50, 0x4B]); // "PK" zip header

      final zip = ZipDecoder().decodeBytes(bytes);
      String read(String name) =>
          utf8.decode(zip.findFile(name)!.content as List<int>);
      expect(read('xl/workbook.xml'), contains('दैनिक हिशोब'));
      final entries = read('xl/worksheets/sheet1.xml');
      expect(entries, contains('तारीख'));
      expect(entries, contains('<v>1500.5</v>'));
      expect(read('xl/worksheets/sheet2.xml'), contains('रमेश &amp; Co'));
      expect(read('xl/worksheets/sheet3.xml'), contains('<v>46328</v>')); // 2 Nov 2026
    });
  });

  group('Backup and restore', () {
    test('a backup restores every entry into an empty book (new PC)', () async {
      final old = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 2, 10));
      await old.init();
      old.addEntry(type: EntryType.sale, amountPaise: 150050, note: 'दूध');
      old.addEntry(type: EntryType.udhaarGiven, amountPaise: 20000, customer: 'रमेश & Co');
      old.addEntry(type: EntryType.paymentReceived, amountPaise: 5000, customer: 'रमेश & Co');

      final bytes = buildHisaabXlsx(
          entries: old.entries, balances: old.balances(), s: const S(AppLang.hi));
      final restored = readHisaabBackup(bytes)!;
      expect(restored.length, 3);

      final fresh = AppState(MemoryStore());
      await fresh.init();
      expect(fresh.mergeEntries(restored), 3);
      expect(fresh.dueFor('रमेश & Co'), 15000);
      expect(fresh.entries.firstWhere((e) => e.type == EntryType.sale).note, 'दूध');

      // Restoring the same file again adds nothing.
      expect(fresh.mergeEntries(readHisaabBackup(bytes)!), 0);
      expect(fresh.entries.length, 3);
    });

    test('a normal Excel file is not treated as a backup', () {
      final bytes = buildXlsx([
        XSheet('Sheet1', columnWidths: const [], rows: [
          [const XCell.text('hello')],
        ]),
      ]);
      expect(readHisaabBackup(bytes), isNull);
      expect(readHisaabBackup(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('backup files are written and old ones trimmed', () async {
      final dir = await Directory.systemTemp.createTemp('hisaab_backup');
      addTearDown(() => dir.delete(recursive: true));
      final bytes = buildXlsx([XSheet('a', columnWidths: const [], rows: const [])]);
      for (var i = 0; i < 4; i++) {
        await File('${dir.path}${Platform.pathSeparator}Hisaab_Backup_2020-01-0${i + 1}_000000.xlsx')
            .writeAsBytes(bytes);
      }
      final file = await writeHisaabBackup(bytes, dir.path, keep: 3);
      expect(await file.exists(), isTrue);
      final left = dir.listSync().whereType<File>().toList();
      expect(left.length, 3);
    });

    test('days since backup', () async {
      var now = DateTime(2026, 11, 2, 22);
      final state = AppState(MemoryStore(), clock: () => now);
      await state.init();
      expect(state.daysSinceBackup(), isNull);
      state.markBackedUp();
      now = DateTime(2026, 11, 3, 8);
      expect(state.daysSinceBackup(), 1);
    });
  });

  group('PIN lock', () {
    late DateTime now;
    late MemoryStore store;
    late AppState state;

    setUp(() async {
      now = DateTime(2026, 11, 2, 10);
      store = MemoryStore();
      state = AppState(store, clock: () => now);
      await state.init();
    });

    test('new book has no PIN; setting one unlocks and is saved hashed', () async {
      expect(state.hasPin, isFalse);
      state.setPin('4821', '12345678');
      expect(state.hasPin, isTrue);
      expect(state.unlocked, isTrue);
      await state.flush();
      final saved = (await store.load()).toJson().toString();
      expect(saved.contains('4821'), isFalse); // the PIN itself is never stored
      expect(saved.contains('12345678'), isFalse);
    });

    test('right PIN unlocks after restart, wrong PIN does not', () async {
      state.setPin('4821', '12345678');
      await state.flush();
      final again = AppState(store, clock: () => now);
      await again.init();
      expect(again.unlocked, isFalse);
      expect(again.unlock('1111'), isFalse);
      expect(again.unlocked, isFalse);
      expect(again.unlock('4821'), isTrue);
      expect(again.unlocked, isTrue);
    });

    test('5 wrong tries lock it for 30 seconds', () {
      state.setPin('4821', '12345678');
      state.lock();
      for (var i = 0; i < 5; i++) {
        expect(state.unlock('0000'), isFalse);
      }
      expect(state.lockoutLeft(), isNotNull);
      expect(state.unlock('4821'), isFalse); // even the right PIN waits
      now = now.add(const Duration(seconds: 31));
      expect(state.lockoutLeft(), isNull);
      expect(state.unlock('4821'), isTrue);
    });

    test('recovery code allows a new PIN and keeps working', () {
      state.setPin('4821', '12345678');
      state.lock();
      expect(state.checkRecoveryCode('00000000'), isFalse);
      expect(state.checkRecoveryCode('12345678'), isTrue);
      state.setPin('9090', '12345678');
      state.lock();
      expect(state.unlock('4821'), isFalse);
      expect(state.unlock('9090'), isTrue);
      state.lock();
      expect(state.checkRecoveryCode('12345678'), isTrue);
    });

    test('changing the PIN makes the old PIN and old recovery code stop working', () {
      state.setPin('4821', '12345678');
      expect(state.checkPin('0000'), isFalse);
      expect(state.checkPin('4821'), isTrue);
      state.setPin('7777', '87654321'); // what Change PIN does
      state.lock();
      expect(state.unlock('4821'), isFalse);
      expect(state.checkRecoveryCode('12345678'), isFalse);
      expect(state.checkRecoveryCode('87654321'), isTrue);
      expect(state.unlock('7777'), isTrue);
    });

    test('PIN must be exactly 4 digits', () {
      expect(() => state.setPin('12', '12345678'), throwsArgumentError);
      expect(() => state.setPin('12a4', '12345678'), throwsArgumentError);
    });
  });

  group('Bills, modes and theme', () {
    late AppState state;
    late MemoryStore store;

    setUp(() async {
      store = MemoryStore();
      state = AppState(store, clock: () => DateTime(2026, 11, 2, 10));
      await state.init();
    });

    test('new books start in simple mode with system theme', () {
      expect(state.simpleMode, isTrue);
      expect(state.themeMode, ThemeMode.system);
      state.cycleTheme();
      expect(state.themeMode, ThemeMode.light);
      state.cycleTheme();
      expect(state.themeMode, ThemeMode.dark);
      state.cycleTheme();
      expect(state.themeMode, ThemeMode.system);
    });

    test('a paid bill is one sale with its items, numbered from 1', () {
      final e = state.saveBill(items: const [
        BillItem(name: 'साखर', qty: 2, pricePaise: 4500),
        BillItem(name: 'Tea', qty: 0.5, pricePaise: 30000),
        BillItem(name: '', qty: 1, pricePaise: 100), // blank line ignored
      ]);
      expect(e.type, EntryType.sale);
      expect(e.amountPaise, 9000 + 15000);
      expect(e.billNo, 1);
      expect(e.items.length, 2);
      expect(state.nextBillNo, 2);
      expect(state.today().moneyIn, 24000);
    });

    test('pay-later bill becomes udhaar for the customer', () {
      state.saveBill(
        items: const [BillItem(name: 'Rice', qty: 5, pricePaise: 6000)],
        customer: 'Sunita',
        payLater: true,
      );
      expect(state.dueFor('Sunita'), 30000);
      expect(() => state.saveBill(items: const [BillItem(name: 'x', qty: 1, pricePaise: 1)], payLater: true),
          throwsArgumentError);
    });

    test('item prices are remembered, most recent first', () {
      state.saveBill(items: const [BillItem(name: 'Sugar', qty: 1, pricePaise: 4500)]);
      state.saveBill(items: const [BillItem(name: 'Milk', qty: 1, pricePaise: 3200)]);
      state.saveBill(items: const [BillItem(name: 'Sugar', qty: 1, pricePaise: 4700)]);
      final known = state.knownItems();
      expect(known.first.key, 'Sugar');
      expect(known.first.value, 4700);
      expect(known.length, 2);
    });

    test('bills and settings survive save, load and Excel backup', () async {
      state.setShopInfo(name: 'Kuthe Kirana', phone: '98xxxxxx01');
      state.setSimpleMode(false);
      state.saveBill(items: const [BillItem(name: 'Dal', qty: 1.5, pricePaise: 12000)]);
      await state.flush();

      final again = AppState(store);
      await again.init();
      expect(again.simpleMode, isFalse);
      expect(again.shopName, 'Kuthe Kirana');
      expect(again.entries.single.items.single.qty, 1.5);
      expect(again.nextBillNo, 2);

      final bytes = buildHisaabXlsx(entries: again.entries, balances: again.balances(), s: const S(AppLang.en));
      final restored = readHisaabBackup(bytes)!;
      expect(restored.single.billNo, 1);
      expect(restored.single.items.single.name, 'Dal');
    });

    test('bill number helpers', () {
      expect(parseQty(''), 1);
      expect(parseQty('०.५'), 0.5);
      expect(parseQty('0'), isNull);
      expect(parsePricePaise('12.50'), 1250);
      expect(formatQty(2), '2');
      expect(formatQty(0.5), '0.5');
      expect(formatQty(1.25), '1.25');
      expect(paiseToInput(4500), '45');
      expect(paiseToInput(1250), '12.50');
    });
  });

  group('Languages', () {
    test('every finished language has every line', () {
      for (final l in AppLang.values.where((l) => !l.isPartial)) {
        final missing = S.keys.where((k) => !S.has(l, k)).toList();
        expect(missing, isEmpty, reason: '${l.englishName} is missing $missing');
      }
    });

    test('Tulu falls back to Kannada, never to blank', () {
      const tulu = S(AppLang.tcy);
      expect(tulu.today, 'ಇನಿ'); // Tulu word
      expect(tulu.makeBill, const S(AppLang.kn).makeBill); // Kannada fallback
    });

    test('all 22 official languages + English + Tulu, none ever blank', () {
      expect(AppLang.values.length, 24);
      for (final l in AppLang.values) {
        for (final k in S.keys) {
          AppLang? x = l;
          var found = false;
          while (x != null && !found) {
            found = S.has(x, k);
            x = x.fallback;
          }
          expect(found, isTrue, reason: '${l.englishName}: $k');
        }
      }
      // Konkani readers fall back to Marathi, Assamese to Bengali, Kashmiri to Urdu.
      expect(AppLang.kok.fallback, AppLang.mr);
      expect(AppLang.asm.fallback, AppLang.bn);
      expect(AppLang.ks.fallback, AppLang.ur);
    });

    test('number templates are filled in every language', () {
      for (final l in AppLang.values) {
        final s = S(l);
        expect(s.lastBackup(3), contains('3'));
        expect(s.restored(7), contains('7'));
        expect(s.tryAgainIn(30), contains('30'));
        expect(s.lastBackup(3).contains('{n}'), isFalse);
      }
    });

    test('local digits per script, typed digits read back', () {
      localDigitSet = AppLang.bn.digits;
      expect(formatRupees(150000, devanagari: true), '₹১,৫০০');
      localDigitSet = AppLang.ur.digits;
      expect(toDigits('2026', true), '۲۰۲۶');
      expect(parseRupeesToPaise('৫০০'), 50000);
      expect(parseRupeesToPaise('۵۰۰'), 50000);
      expect(parseRupeesToPaise('೫೦೦'), 50000);
      expect(parseRupeesToPaise('᱕᱐᱐'), 50000); // Ol Chiki
      expect(parseRupeesToPaise('꯵꯰꯰'), 50000); // Meetei Mayek
      localDigitSet = AppLang.hi.digits;
    });

    test('Urdu, Kashmiri and Sindhi are right to left; new languages are beta', () {
      expect(AppLang.values.where((l) => l.isRtl), [AppLang.ur, AppLang.ks, AppLang.sd]);
      expect(AppLang.mr.isBeta, isFalse);
      expect(AppLang.ta.isBeta, isTrue);
    });
  });

  group('Staff on expenses', () {
    test('a name on an expense is not a customer', () async {
      final state = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 2, 15));
      await state.init();
      state.addEntry(type: EntryType.expense, amountPaise: 2000, customer: 'Ram', note: 'water');
      state.addEntry(type: EntryType.sale, amountPaise: 10000, customer: 'Shubham');
      expect(state.balances().map((b) => b.name), ['Shubham']);
      expect(state.recentCustomers(), ['Shubham']);
      expect(state.recentSpenders(), ['Ram']);
      expect(state.entriesFor('Ram'), isEmpty);
      expect(state.today().moneyOut, 2000); // still counted as money out
      state.addEntry(type: EntryType.expense, amountPaise: 3000, customer: 'ram');
      expect(state.paidToTotals().single.totalPaise, 5000);
      expect(state.expensesFor('RAM').length, 2);
    });
  });

  group('Speak an entry', () {
    ParsedEntry p(String t) => EntryParser.parse(t);

    test('udhaar with a name', () {
      final e = p('Ram ko 200 udhaar');
      expect(e.type, EntryType.udhaarGiven);
      expect(e.amountPaise, 20000);
      expect(e.name, 'Ram');
    });

    test('sale, expense with note, payment', () {
      expect(p('500 ki sale').type, EntryType.sale);
      expect(p('500 ki sale').amountPaise, 50000);
      final chai = p('chai 50 kharcha');
      expect(chai.type, EntryType.expense);
      expect(chai.note, 'Chai');
      final pay = p('Sunita ne 1000 jama kiye');
      expect(pay.type, EntryType.paymentReceived);
      expect(pay.name, 'Sunita');
      expect(p('Mohan ne 500 phonepe se diye').mode, PayMode.upi);
      expect(p('Mohan ne 500 phonepe se diye').type, EntryType.paymentReceived);
    });

    test('Devanagari words and digits, hazar and commas', () {
      final e = p('राम को ३०० उधार');
      expect(e.type, EntryType.udhaarGiven);
      expect(e.amountPaise, 30000);
      expect(e.name, 'राम');
      expect(p('2 hazar ki bikri').amountPaise, 200000);
      expect(p('Shyam 1,500 udhaar').amountPaise, 150000);
      expect(p('दूध 40 रुपये खर्च').note, 'दूध');
    });

    test('no amount heard', () {
      expect(p('Ram udhaar').amountPaise, isNull);
      expect(p('just talking').typeFromWords, isFalse);
    });
  });

  group('Cash / UPI, edit and undo', () {
    late AppState state;
    setUp(() async {
      state = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 3, 10));
      await state.init();
    });

    test('today splits cash and UPI and knows the cash drawer', () {
      state.addEntry(type: EntryType.sale, amountPaise: 50000, mode: PayMode.cash);
      state.addEntry(type: EntryType.sale, amountPaise: 30000, mode: PayMode.upi);
      state.addEntry(type: EntryType.expense, amountPaise: 10000, mode: PayMode.cash);
      state.addEntry(type: EntryType.udhaarGiven, amountPaise: 9900, customer: 'Ram', mode: PayMode.upi);
      final t = state.today();
      expect(t.cashIn, 50000);
      expect(t.upiIn, 30000);
      expect(t.cashInHand, 40000);
      expect(state.entries.first.mode, isNull); // udhaar has no cash/UPI
      expect(state.lastPayMode, PayMode.cash);
    });

    test('old entries without a mode count as cash', () {
      final e = Entry.tryFromJson({'id': 'x', 'type': 'sale', 'amount': 100, 'at': '2026-11-03T09:00:00'})!;
      expect(e.payMode, PayMode.cash);
    });

    test('edit keeps id and time; delete can be undone', () {
      final e = state.addEntry(type: EntryType.sale, amountPaise: 50000, note: 'milk');
      state.updateEntry(e.copyWith(amountPaise: 55000, note: '', mode: PayMode.upi));
      final fixed = state.entries.single;
      expect(fixed.id, e.id);
      expect(fixed.createdAt, e.createdAt);
      expect(fixed.amountPaise, 55000);
      expect(fixed.note, isNull);
      expect(fixed.payMode, PayMode.upi);
      state.deleteEntry(e.id);
      expect(state.entries, isEmpty);
      state.restoreEntry(fixed);
      expect(state.entries.single.amountPaise, 55000);
    });

    test('mode survives a backup and restore', () {
      state.addEntry(type: EntryType.sale, amountPaise: 30000, mode: PayMode.upi);
      final bytes = buildHisaabXlsx(entries: state.entries, balances: state.balances(), s: const S(AppLang.en));
      expect(readHisaabBackup(bytes)!.single.mode, PayMode.upi);
    });
  });

  group('Reports, reminders, UPI and auto backup', () {
    test('report covers every day in the range with top expenses', () async {
      var now = DateTime(2026, 11, 1, 10);
      final state = AppState(MemoryStore(), clock: () => now);
      await state.init();
      state.addEntry(type: EntryType.sale, amountPaise: 100000);
      state.addEntry(type: EntryType.expense, amountPaise: 20000, customer: 'Ram');
      now = DateTime(2026, 11, 3, 10);
      state.addEntry(type: EntryType.sale, amountPaise: 40000);
      state.addEntry(type: EntryType.expense, amountPaise: 5000, customer: 'ram');
      state.addEntry(type: EntryType.expense, amountPaise: 1000, note: 'chai');
      final r = state.report(DateTime(2026, 10, 28), DateTime(2026, 11, 3));
      expect(r.days.length, 7);
      expect(r.summary.moneyIn, 140000);
      expect(r.bestDay!.day, DateTime(2026, 11, 1));
      expect(r.topExpenses.first.value, 25000); // Ram + ram together
      expect(r.activeDays, 2);
    });

    test('phone numbers and UPI IDs', () {
      expect(normalizeIndianPhone('98765 43210'), '919876543210');
      expect(normalizeIndianPhone('+91-98765-43210'), '919876543210');
      expect(normalizeIndianPhone('098765 43210'), '919876543210');
      expect(normalizeIndianPhone('12345'), isNull);
      expect(AppState.isValidUpi('ramstore@okaxis'), isTrue);
      expect(AppState.isValidUpi('ram store'), isFalse);
    });

    test('customer phone, shop UPI and auto backup flags are saved', () async {
      final store = MemoryStore();
      var now = DateTime(2026, 11, 3, 10);
      final state = AppState(store, clock: () => now);
      await state.init();
      state.setCustomerPhone('Ram Kumar', '98765 43210');
      expect(state.setShopUpi('bad upi'), isFalse);
      expect(state.setShopUpi('ram@okaxis'), isTrue);
      expect(state.autoBackupDue(), isFalse); // no folder yet
      state.setBackupDir('/tmp');
      state.addEntry(type: EntryType.sale, amountPaise: 100);
      expect(state.autoBackupDue(), isTrue);
      state.markBackedUp();
      expect(state.autoBackupDue(), isFalse);
      now = DateTime(2026, 11, 4, 9);
      expect(state.autoBackupDue(), isTrue);
      await state.flush();
      final again = AppState(store);
      await again.init();
      expect(again.phoneFor('ram kumar'), '9876543210');
      expect(again.shopUpi, 'ram@okaxis');
      expect(again.autoBackup, isTrue);
    });
  });
}
