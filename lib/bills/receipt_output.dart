import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// A picture of the receipt exactly as shown on screen. Drawing it with
/// Flutter keeps Marathi/Hindi letters correct (PDF text tools often break
/// Devanagari joined letters).
class ReceiptImage {
  const ReceiptImage(this.png, this.width, this.height);
  final Uint8List png;
  final int width;
  final int height;
}

/// Captures whatever is inside the RepaintBoundary with [key].
Future<ReceiptImage> captureReceipt(GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final result = ReceiptImage(data!.buffer.asUint8List(), image.width, image.height);
  image.dispose();
  return result;
}

/// Opens the Windows print dialog with the receipt sized for 80 mm
/// receipt paper (any normal printer works too).
Future<void> printReceipt(ReceiptImage img, {required String name}) async {
  const mm = PdfPageFormat.mm;
  const contentWidth = 72 * mm;
  final contentHeight = contentWidth * img.height / img.width;
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat(80 * mm, contentHeight + 8 * mm, marginAll: 4 * mm),
    build: (_) => pw.Image(pw.MemoryImage(img.png), fit: pw.BoxFit.contain),
  ));
  final bytes = await doc.save();
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
}

/// Saves the receipt as a PNG in Documents\Hisaab\Bills, ready to send
/// on WhatsApp.
Future<File> saveReceiptImage(ReceiptImage img, int billNo,
    {Future<Directory> Function()? directory}) async {
  final base = await (directory ?? getApplicationDocumentsDirectory)();
  final sep = Platform.pathSeparator;
  final dir = Directory('${base.path}${sep}Hisaab${sep}Bills');
  await dir.create(recursive: true);
  final file = File('${dir.path}${sep}Bill_$billNo.png');
  await file.writeAsBytes(img.png, flush: true);
  return file;
}
