import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A tiny .xlsx writer: just enough for clean, real Excel files
/// (bold headers, rupee numbers, real dates, frozen header row).
class XCell {
  const XCell.text(this.text, {this.bold = false}) : number = null, style = bold ? 1 : 0;
  const XCell.money(num value) : text = null, number = value, bold = false, style = 2;
  XCell.date(DateTime d)
      : text = null,
        number = DateTime.utc(d.year, d.month, d.day)
            .difference(DateTime.utc(1899, 12, 30))
            .inDays,
        bold = false,
        style = 3;

  final String? text;
  final num? number;
  final bool bold;
  final int style; // index into cellXfs in styles.xml
}

class XSheet {
  XSheet(this.name, {required this.columnWidths, required this.rows, this.hidden = false});
  final String name;

  /// Hidden sheets don't show as tabs in Excel (used for restore data).
  final bool hidden;
  final List<double> columnWidths;
  final List<List<XCell>> rows;
}

Uint8List buildXlsx(List<XSheet> sheets) {
  final files = <String, String>{
    '[Content_Types].xml': _contentTypes(sheets.length),
    '_rels/.rels': _rootRels,
    'xl/workbook.xml': _workbook(sheets),
    'xl/_rels/workbook.xml.rels': _workbookRels(sheets.length),
    'xl/styles.xml': _styles,
    for (var i = 0; i < sheets.length; i++)
      'xl/worksheets/sheet${i + 1}.xml': _sheet(sheets[i]),
  };
  final archive = Archive();
  files.forEach((name, xml) {
    final bytes = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String columnName(int index) {
  var n = index + 1;
  var s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _sheetName(String name) {
  final clean = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  return clean.length > 31 ? clean.substring(0, 31) : clean;
}

const _ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

String _contentTypes(int n) => '$_head'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '${[for (var i = 1; i <= n; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
    '</Types>';

const _rootRels = '$_head'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="$_rel/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbook(List<XSheet> sheets) => '$_head'
    '<workbook xmlns="$_ns" xmlns:r="$_rel"><sheets>'
    '${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_esc(_sheetName(sheets[i].name))}" sheetId="${i + 1}"${sheets[i].hidden ? ' state="hidden"' : ''} r:id="rId${i + 1}"/>'].join()}'
    '</sheets></workbook>';

String _workbookRels(int n) => '$_head'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '${[for (var i = 1; i <= n; i++) '<Relationship Id="rId$i" Type="$_rel/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
    '<Relationship Id="rId${n + 1}" Type="$_rel/styles" Target="styles.xml"/>'
    '</Relationships>';

// cellXfs: 0 normal, 1 bold header, 2 money (#,##0.00), 3 date (dd/mm/yyyy)
const _styles = '$_head'
    '<styleSheet xmlns="$_ns">'
    '<numFmts count="1"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/></numFmts>'
    '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="2"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="4">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

String _sheet(XSheet sheet) {
  final out = StringBuffer('$_head<worksheet xmlns="$_ns">');
  out.write('<sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews>');
  if (sheet.columnWidths.isNotEmpty) {
    out.write('<cols>');
    for (var i = 0; i < sheet.columnWidths.length; i++) {
      out.write('<col min="${i + 1}" max="${i + 1}" width="${sheet.columnWidths[i]}" customWidth="1"/>');
    }
    out.write('</cols>');
  }
  out.write('<sheetData>');
  for (var r = 0; r < sheet.rows.length; r++) {
    out.write('<row r="${r + 1}">');
    final row = sheet.rows[r];
    for (var c = 0; c < row.length; c++) {
      final cell = row[c];
      final ref = '${columnName(c)}${r + 1}';
      if (cell.number != null) {
        out.write('<c r="$ref" s="${cell.style}"><v>${cell.number}</v></c>');
      } else if (cell.text != null && cell.text!.isNotEmpty) {
        out.write('<c r="$ref" s="${cell.style}" t="inlineStr"><is><t xml:space="preserve">'
            '${_esc(cell.text!)}</t></is></c>');
      }
    }
    out.write('</row>');
  }
  out.write('</sheetData></worksheet>');
  return out.toString();
}
