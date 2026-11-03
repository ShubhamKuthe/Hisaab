import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../state/app_state.dart';
import '../utils/platform_share.dart';
import 'hisaab_export.dart';

/// "Backup now": writes the full book as Excel into the backup folder.
/// Asks for the folder the first time (or when [chooseFolder] is true,
/// or when the old folder is gone, e.g. the pen drive is unplugged).
Future<void> runBackup(BuildContext context, {bool chooseFolder = false}) async {
  final state = AppScope.of(context);
  final s = state.s;
  final messenger = ScaffoldMessenger.of(context);

  // Phone: make the file, then share it to Google Drive / WhatsApp / Gmail.
  if (isPhone) {
    try {
      final bytes = buildHisaabXlsx(entries: state.entries, balances: state.balances(), s: s);
      final file = await saveHisaabExport(bytes);
      await shareFile(file, text: 'Hisaab backup');
      state.markBackedUp();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: HisaabColors.moneyOut,
        content: Text('${s.backupFailed}: $e', style: const TextStyle(fontSize: 16)),
      ));
    }
    return;
  }

  try {
    String? folder = state.backupDir;
    if (chooseFolder || folder == null || !await Directory(folder).exists()) {
      folder = await getDirectoryPath(confirmButtonText: s.chooseBackupFolder);
      if (folder == null) return; // cancelled
      state.setBackupDir(folder);
    }

    final bytes = buildHisaabXlsx(entries: state.entries, balances: state.balances(), s: s);
    final file = await writeHisaabBackup(bytes, folder);
    state.markBackedUp();

    final warn = _looksLikeThisComputer(folder) ? '\n⚠ ${s.sameComputerWarning}' : '';
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 10),
      backgroundColor: warn.isEmpty ? HisaabColors.moneyIn : HisaabColors.udhaar,
      content: Text('✓ ${s.backupDone}\n${file.path}$warn', style: const TextStyle(fontSize: 16)),
      action: SnackBarAction(
        label: s.openFolder,
        textColor: Colors.white,
        onPressed: () => showInFolder(file),
      ),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      backgroundColor: HisaabColors.moneyOut,
      content: Text('${s.backupFailed}: $e', style: const TextStyle(fontSize: 16)),
    ));
  }
}

/// The daily automatic backup: runs quietly (no folder picker) when the
/// shop hasn't been backed up today. Skips if the folder isn't there
/// (pen drive not plugged in) - the backup line turns red after a week.
/// [force] backs up even if one was already made today (end of day).
Future<File?> autoBackupIfDue(AppState state, {bool force = false}) async {
  if (force ? (!state.autoBackup || state.backupDir == null || state.entries.isEmpty) : !state.autoBackupDue()) {
    return null;
  }
  final folder = state.backupDir!;
  try {
    if (!await Directory(folder).exists()) return null;
    final bytes = buildHisaabXlsx(entries: state.entries, balances: state.balances(), s: state.s);
    final file = await writeHisaabBackup(bytes, folder);
    state.markBackedUp();
    return file;
  } catch (_) {
    return null;
  }
}

/// "Restore from backup": pick a Hisaab Excel backup and add back anything
/// missing. Safe to run more than once - nothing is duplicated or deleted.
Future<void> runRestore(BuildContext context) async {
  final state = AppScope.of(context);
  final s = state.s;
  final messenger = ScaffoldMessenger.of(context);

  try {
    final picked = await openFile(
      acceptedTypeGroups: const [XTypeGroup(label: 'Excel', extensions: <String>['xlsx'])],
      initialDirectory: state.backupDir,
      confirmButtonText: s.restore,
    );
    if (picked == null) return;
    final entries = readHisaabBackup(await picked.readAsBytes());
    if (entries == null) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: HisaabColors.moneyOut,
        content: Text(s.notABackup, style: const TextStyle(fontSize: 16)),
      ));
      return;
    }
    final added = state.mergeEntries(entries);
    messenger.showSnackBar(SnackBar(
      backgroundColor: HisaabColors.moneyIn,
      content: Text('✓ ${s.restored(added)}', style: const TextStyle(fontSize: 16)),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      backgroundColor: HisaabColors.moneyOut,
      content: Text('${s.notABackup}: $e', style: const TextStyle(fontSize: 16)),
    ));
  }
}

/// "Excel file for your CA": a copy in Documents\Hisaab.
Future<void> runExport(BuildContext context) async {
  final state = AppScope.of(context);
  final s = state.s;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = buildHisaabXlsx(entries: state.entries, balances: state.balances(), s: s);
    final file = await saveHisaabExport(bytes);
    if (isPhone) {
      await shareFile(file, text: 'Hisaab');
      return;
    }
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      backgroundColor: HisaabColors.moneyIn,
      content: Text('✓ ${s.exportDone}\n${file.path}', style: const TextStyle(fontSize: 16)),
      action: SnackBarAction(
        label: s.openFolder,
        textColor: Colors.white,
        onPressed: () => showInFolder(file),
      ),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      backgroundColor: HisaabColors.moneyOut,
      content: Text('${s.exportFailed}: $e', style: const TextStyle(fontSize: 16)),
    ));
  }
}

/// A folder on the C: drive that isn't synced to the cloud dies with the PC.
bool _looksLikeThisComputer(String folder) {
  if (!Platform.isWindows) return false;
  final synced = RegExp('google ?drive|onedrive|dropbox', caseSensitive: false);
  return folder.toUpperCase().startsWith('C:') && !synced.hasMatch(folder);
}
