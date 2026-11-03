import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Reads the rows of one sheet (by name) from an .xlsx file as text.
///
/// Handles files written by Hisaab (inline strings) and the same file after
/// someone opened and saved it in Excel or LibreOffice (shared strings).
/// Returns null if the file isn't an .xlsx or the sheet isn't there.
List<List<String>>? readXlsxSheet(Uint8List bytes, String sheetName) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return null;
  }

  String? part(String name) {
    final f = zip.findFile(name);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final workbook = part('xl/workbook.xml');
  final rels = part('xl/_rels/workbook.xml.rels');
  if (workbook == null || rels == null) return null;

  // 1. sheet name -> relationship id
  String? relId;
  for (final m in RegExp(r'<sheet\b([^>]*)/?>').allMatches(workbook)) {
    final attrs = _attrs(m.group(1)!);
    if (_unescape(attrs['name'] ?? '') == sheetName) {
      relId = attrs['r:id'];
      break;
    }
  }
  if (relId == null) return null;

  // 2. relationship id -> sheet file
  String? target;
  for (final m in RegExp(r'<Relationship\b([^>]*)/?>').allMatches(rels)) {
    final attrs = _attrs(m.group(1)!);
    if (attrs['Id'] == relId) {
      target = attrs['Target'];
      break;
    }
  }
  if (target == null) return null;
  final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
  final sheet = part(path);
  if (sheet == null) return null;

  // 3. shared strings (only present after Excel/LibreOffice re-saves)
  final shared = <String>[];
  final sst = part('xl/sharedStrings.xml');
  if (sst != null) {
    for (final si in RegExp(r'<si\b[^>]*>(.*?)</si>', dotAll: true).allMatches(sst)) {
      shared.add(_text(si.group(1)!));
    }
  }

  // 4. rows and cells
  final rows = <List<String>>[];
  final rowRe = RegExp(r'<row\b([^>]*?)(?:/>|>(.*?)</row>)', dotAll: true);
  final cellRe = RegExp(r'<c\b([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true);
  for (final rm in rowRe.allMatches(sheet)) {
    final rowAttrs = _attrs(rm.group(1)!);
    final rowIndex = (int.tryParse(rowAttrs['r'] ?? '') ?? rows.length + 1) - 1;
    while (rows.length < rowIndex) {
      rows.add(<String>[]); // keep row positions for skipped empty rows
    }
    final cells = <String>[];
    for (final cm in cellRe.allMatches(rm.group(2) ?? '')) {
      final attrs = _attrs(cm.group(1)!);
      final inner = cm.group(2) ?? '';
      final col = _colIndex(attrs['r']) ?? cells.length;
      while (cells.length < col) {
        cells.add('');
      }
      String value;
      final type = attrs['t'];
      if (type == 'inlineStr') {
        value = _text(inner);
      } else {
        final v = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(inner)?.group(1);
        if (type == 's' && v != null) {
          final i = int.tryParse(v);
          value = (i != null && i >= 0 && i < shared.length) ? shared[i] : '';
        } else {
          value = v == null ? '' : _unescape(v);
        }
      }
      cells.add(value);
    }
    rows.add(cells);
  }
  return rows;
}

Map<String, String> _attrs(String s) => {
      for (final m in RegExp(r'([\w:]+)="([^"]*)"').allMatches(s)) m.group(1)!: m.group(2)!,
    };

/// Joins every <t>…</t> run (rich text has several); skips empty <t/>.
String _text(String xml) => RegExp(r'<t(?:\s[^>/]*)?>(.*?)</t>', dotAll: true)
    .allMatches(xml)
    .map((m) => _unescape(m.group(1)!))
    .join();

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

int? _colIndex(String? ref) {
  if (ref == null) return null;
  final letters = RegExp(r'^[A-Z]+').firstMatch(ref)?.group(0);
  if (letters == null) return null;
  var n = 0;
  for (final c in letters.codeUnits) {
    n = n * 26 + (c - 64);
  }
  return n - 1;
}
