import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../l10n/strings.dart';
import '../models/entry.dart';
import '../state/app_state.dart';
import 'xlsx_reader.dart';
import 'xlsx_writer.dart';

/// Name of the hidden sheet that holds exact data for restoring.
const backupSheetName = 'hisaab_data';
const _backupHeader = ['id', 'type', 'amount_paise', 'at', 'customer', 'note', 'bill_no', 'items', 'mode'];

/// Builds the Excel file: all entries, customer dues and a daily summary,
/// with headings in the shopkeeper's language.
Uint8List buildHisaabXlsx({
  required List<Entry> entries,
  required List<CustomerBalance> balances,
  required S s,
}) {
  double rupees(int paise) => paise / 100;
  final oldestFirst = entries.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  // Sheet 1: every entry, like the paper book.
  final entryRows = <List<XCell>>[
    [
      for (final h in [s.colDate, s.colTime, s.colType, s.customers, s.colAmount, s.payMode, s.note])
        XCell.text(h, bold: true),
    ],
    for (final e in oldestFirst)
      [
        XCell.date(e.createdAt),
        XCell.text('${e.createdAt.hour.toString().padLeft(2, '0')}:'
            '${e.createdAt.minute.toString().padLeft(2, '0')}'),
        XCell.text(s.typeLabel(e.type)),
        XCell.text(e.customer ?? ''),
        XCell.money(rupees(e.amountPaise)),
        XCell.text(e.type.hasPayMode ? (e.payMode == PayMode.upi ? s.upi : s.cash) : ''),
        XCell.text(e.note ?? ''),
      ],
  ];

  // Sheet 2: who owes how much.
  final customerRows = <List<XCell>>[
    [XCell.text(s.customerName, bold: true), XCell.text(s.colDue, bold: true)],
    for (final b in balances)
      [XCell.text(b.name), XCell.money(rupees(b.duePaise))],
  ];

  // Sheet 3: one line per day.
  final days = <DateTime, List<int>>{}; // [in, out, udhaar]
  for (final e in oldestFirst) {
    final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
    final t = days.putIfAbsent(d, () => [0, 0, 0]);
    if (e.type.isMoneyIn) {
      t[0] += e.amountPaise;
    } else if (e.type == EntryType.expense) {
      t[1] += e.amountPaise;
    } else {
      t[2] += e.amountPaise;
    }
  }
  final dailyRows = <List<XCell>>[
    [
      for (final h in [s.colDate, s.moneyIn, s.moneyOut, s.udhaarGiven, s.colNet])
        XCell.text(h, bold: true),
    ],
    for (final day in days.entries)
      [
        XCell.date(day.key),
        XCell.money(rupees(day.value[0])),
        XCell.money(rupees(day.value[1])),
        XCell.money(rupees(day.value[2])),
        XCell.money(rupees(day.value[0] - day.value[1])),
      ],
  ];

  // Sheet 4 (hidden): exact data, so the app can restore from this file.
  final dataRows = <List<XCell>>[
    [for (final h in _backupHeader) XCell.text(h)],
    for (final e in oldestFirst)
      [
        XCell.text(e.id),
        XCell.text(e.type.name),
        XCell.text(e.amountPaise.toString()),
        XCell.text(e.createdAt.toIso8601String()),
        XCell.text(e.customer ?? ''),
        XCell.text(e.note ?? ''),
        XCell.text(e.billNo?.toString() ?? ''),
        XCell.text(e.items.isEmpty ? '' : jsonEncode([for (final i in e.items) i.toJson()])),
        XCell.text(e.mode?.name ?? ''),
      ],
  ];

  return buildXlsx([
    XSheet(s.history, columnWidths: [13, 8, 18, 24, 14, 10, 30], rows: entryRows),
    XSheet(s.sheetCustomers, columnWidths: [28, 16], rows: customerRows),
    XSheet(s.sheetDaily, columnWidths: [13, 16, 16, 16, 16], rows: dailyRows),
    XSheet(backupSheetName, columnWidths: const [], rows: dataRows, hidden: true),
  ]);
}

/// Reads the entries back out of a Hisaab Excel backup.
/// Returns null if the file is not a Hisaab backup.
List<Entry>? readHisaabBackup(Uint8List bytes) {
  final rows = readXlsxSheet(bytes, backupSheetName);
  if (rows == null || rows.isEmpty) return null;
  final header = rows.first;
  if (header.length < 4 || header[0] != 'id' || header[1] != 'type') return null;
  final entries = <Entry>[];
  for (final r in rows.skip(1)) {
    String at(int i) => i < r.length ? r[i].trim() : '';
    final amount = int.tryParse(at(2).split('.').first);
    if (amount == null) continue;
    final e = Entry.tryFromJson({
      'id': at(0),
      'type': at(1),
      'amount': amount,
      'at': at(3),
      if (at(4).isNotEmpty) 'customer': at(4),
      if (at(5).isNotEmpty) 'note': at(5),
      if (int.tryParse(at(6)) != null) 'billNo': int.parse(at(6)),
      if (at(7).isNotEmpty) 'items': _decodeItems(at(7)),
      if (at(8).isNotEmpty) 'mode': at(8),
    });
    if (e != null && e.id.isNotEmpty && e.amountPaise > 0) entries.add(e);
  }
  return entries;
}

Object? _decodeItems(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}

/// Writes a backup into [folder] and keeps only the newest [keep] backups there.
Future<File> writeHisaabBackup(Uint8List bytes, String folder, {int keep = 30}) async {
  final dir = Directory(folder);
  if (!await dir.exists()) {
    throw FileSystemException('Backup folder not found', folder);
  }
  final sep = Platform.pathSeparator;
  final file = File('${dir.path}$sep${_stampedName('Hisaab_Backup')}');
  await file.writeAsBytes(bytes, flush: true);

  final old = await dir
      .list()
      .where((f) => f is File && f.uri.pathSegments.last.startsWith('Hisaab_Backup_') && f.path.endsWith('.xlsx'))
      .cast<File>()
      .toList();
  old.sort((a, b) => b.path.compareTo(a.path));
  for (final f in old.skip(keep)) {
    try {
      await f.delete();
    } catch (_) {/* a file open in Excel can't be deleted; skip it */}
  }
  return file;
}

String _stampedName(String prefix) {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${prefix}_${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}.xlsx';
}

/// Saves to Documents\Hisaab\Hisaab_YYYY-MM-DD_HHMM.xlsx and returns the file.
Future<File> saveHisaabExport(Uint8List bytes, {Future<Directory> Function()? directory}) async {
  final base = await (directory ?? getApplicationDocumentsDirectory)();
  final sep = Platform.pathSeparator;
  final dir = Directory('${base.path}${sep}Hisaab');
  await dir.create(recursive: true);
  final file = File('${dir.path}$sep${_stampedName('Hisaab')}');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// Opens File Explorer with the file selected (Windows only).
Future<void> showInFolder(File file) async {
  if (!Platform.isWindows) return;
  try {
    await Process.run('explorer.exe', ['/select,${file.path}']);
  } catch (_) {
    // Explorer not available: the snackbar already shows the path.
  }
}
