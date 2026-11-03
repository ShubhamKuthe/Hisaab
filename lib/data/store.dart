import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'hisaab_data.dart';

/// Where the book is kept. Swappable so we can move to SQLite or a cloud
/// sync later without touching the screens.
abstract class HisaabStore {
  Future<HisaabData> load();
  Future<void> save(HisaabData data);
}

/// In-memory store, used by tests.
class MemoryStore implements HisaabStore {
  MemoryStore([HisaabData? initial]) : _data = initial ?? HisaabData();
  HisaabData _data;
  int saveCount = 0;

  @override
  Future<HisaabData> load() async => _data.copy();

  @override
  Future<void> save(HisaabData data) async {
    _data = data.copy();
    saveCount++;
  }
}

/// Offline store: one JSON file in the app's data folder.
///
/// * Writes go to a temp file first and are then swapped in, so a power cut
///   mid-save can't corrupt the book.
/// * Keeps one backup per day for the last [keepBackups] days.
/// * If the main file is ever damaged, it is set aside and the newest
///   readable backup is loaded instead.
class JsonFileStore implements HisaabStore {
  JsonFileStore({Future<Directory> Function()? directory, this.keepBackups = 7})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  final int keepBackups;
  static const _fileName = 'hisaab_data.json';
  static final _sep = Platform.pathSeparator;

  Future<Directory> _root() async {
    final d = await _directory();
    await d.create(recursive: true);
    return d;
  }

  Future<Directory> _backupDir() async {
    final d = Directory('${(await _root()).path}${_sep}backups');
    await d.create(recursive: true);
    return d;
  }

  Future<File> _mainFile() async => File('${(await _root()).path}$_sep$_fileName');

  @override
  Future<HisaabData> load() async {
    final file = await _mainFile();
    if (await file.exists()) {
      try {
        return HisaabData.fromJson(jsonDecode(await file.readAsString()));
      } catch (_) {
        // Keep the damaged file for inspection, then fall back to a backup.
        final stamp = DateTime.now().millisecondsSinceEpoch;
        await file.copy('${file.path}.damaged-$stamp');
      }
    } else {
      return HisaabData();
    }
    for (final backup in await _backupsNewestFirst()) {
      try {
        return HisaabData.fromJson(jsonDecode(await backup.readAsString()));
      } catch (_) {
        continue;
      }
    }
    return HisaabData();
  }

  @override
  Future<void> save(HisaabData data) async {
    final file = await _mainFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    await tmp.rename(file.path);
    await _dailyBackup(file);
  }

  Future<void> _dailyBackup(File file) async {
    final now = DateTime.now();
    final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final dir = await _backupDir();
    // Overwrite today's backup so it always holds the latest state of the day.
    await file.copy('${dir.path}${_sep}hisaab_$day.json');
    final all = await _backupsNewestFirst();
    for (final old in all.skip(keepBackups)) {
      await old.delete();
    }
  }

  Future<List<File>> _backupsNewestFirst() async {
    final dir = await _backupDir();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
