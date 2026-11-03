import 'package:flutter/material.dart';

import '../app.dart';
import '../export/backup_actions.dart';
import '../utils/format.dart';
import '../utils/platform_share.dart';

/// One calm line on the home screen:  ☁  Last backup: 3 days ago   [Backup]  ⋮
/// The date turns red only when it has been more than a week (or never).
class BackupCard extends StatelessWidget {
  const BackupCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.s;
    final days = state.daysSinceBackup();
    final overdue = days == null || days > 7;
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: s.backupExplain,
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
          child: Row(
            children: [
              Icon(Icons.cloud_done_outlined,
                  color: overdue ? HisaabColors.moneyOut : HisaabColors.moneyIn),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  toDigits(s.lastBackup(days), state.devanagariDigits),
                  style: TextStyle(
                    fontSize: 15,
                    color: overdue ? HisaabColors.moneyOut : mutedText(context),
                    fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: HisaabColors.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: () => runBackup(context),
                child: Text(s.backupNow, style: const TextStyle(fontSize: 16)),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  switch (v) {
                    case 'folder':
                      runBackup(context, chooseFolder: true);
                    case 'restore':
                      runRestore(context);
                    case 'export':
                      runExport(context);
                    case 'auto':
                      state.setAutoBackup(!state.autoBackup);
                  }
                },
                itemBuilder: (_) => [
                  if (!isPhone) PopupMenuItem(
                    value: 'folder',
                    child: ListTile(leading: const Icon(Icons.folder_open), title: Text(s.chooseBackupFolder)),
                  ),
                  PopupMenuItem(
                    value: 'restore',
                    child: ListTile(leading: const Icon(Icons.settings_backup_restore), title: Text(s.restore)),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(leading: const Icon(Icons.table_view), title: Text(s.exportForCa)),
                  ),
                  if (!isPhone) const PopupMenuDivider(),
                  if (!isPhone) CheckedPopupMenuItem(
                    value: 'auto',
                    checked: state.autoBackup,
                    child: Text(s.autoBackup),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
