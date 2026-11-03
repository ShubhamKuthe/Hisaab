import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// "98765 43210", "+91 98765-43210", "098765..." -> "919876543210".
/// Returns null if it isn't a usable phone number.
String? normalizeIndianPhone(String? raw) {
  if (raw == null) return null;
  final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 10) return '91$d';
  if (d.length == 11 && d.startsWith('0')) return '91${d.substring(1)}';
  if (d.length >= 11 && d.length <= 15) return d; // already has a country code
  return null;
}

/// Opens WhatsApp with [text] typed in, to [phone] if given (else WhatsApp
/// asks who to send it to). Nothing is sent until the shopkeeper presses Send.
/// If WhatsApp can't be opened, the text is copied so it can be pasted.
/// Returns true when WhatsApp (app or web) opened.
Future<bool> openWhatsApp(String text, {String? phone}) async {
  final p = normalizeIndianPhone(phone);
  final enc = Uri.encodeComponent(text);
  final tries = <Uri>[
    // WhatsApp Desktop on Windows answers whatsapp:// directly.
    if (Platform.isWindows || Platform.isMacOS)
      Uri.parse('whatsapp://send?${p != null ? 'phone=$p&' : ''}text=$enc'),
    Uri.parse('https://wa.me/${p ?? ''}?text=$enc'),
  ];
  for (final u in tries) {
    try {
      if (await launchUrl(u, mode: LaunchMode.externalApplication)) return true;
    } catch (_) {/* try the next way */}
  }
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}
