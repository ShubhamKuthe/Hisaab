import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// True on Android / iPhone. Phones have no "folders" a shopkeeper can find,
/// so files are handed to the share sheet (WhatsApp, Google Drive, Gmail...).
bool get isPhone => Platform.isAndroid || Platform.isIOS;

/// Opens the phone's share sheet with [file].
Future<void> shareFile(File file, {String? text}) async {
  await Share.shareXFiles([XFile(file.path)], text: text);
}
