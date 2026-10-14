import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'db_manager.dart';
import 'library_events.dart';
import 'native_bridge.dart';

/// Backups are a zip of the database plus the songs/ folder (page images and
/// annotations), mirroring the app's documents directory layout.
const _dbEntryName = 'sheet_music_viewer.db';
const _songsDirName = 'songs';

Future<void> exportLibrary(BuildContext context) async {
  final docs = await getApplicationDocumentsDirectory();
  final tmp = await getTemporaryDirectory();
  final now = DateTime.now();
  final stamp = "${now.year}-${_two(now.month)}-${_two(now.day)}";
  final fileName = "sheet_music_backup_$stamp.zip";
  final zipPath = join(tmp.path, fileName);

  if (!context.mounted) return;
  _showBusy(context, "Creating backup...");
  bool saved = false;
  String? error;
  try {
    // Close the database so everything is flushed to the file being copied.
    await DbManager.instance.close();
    final encoder = ZipFileEncoder();
    // Page images are already-compressed JPEGs, so store rather than deflate.
    encoder.create(zipPath, level: 0);
    await encoder.addFile(File(await DbManager.instance.databasePath), _dbEntryName);
    final songsDir = Directory(join(docs.path, _songsDirName));
    if (songsDir.existsSync()) {
      await encoder.addDirectory(songsDir);
    }
    encoder.addArchiveFile(ArchiveFile.string(
        'backup_info.json',
        jsonEncode({'app': 'sheet_music_viewer', 'format': 1, 'created': now.toIso8601String()})));
    await encoder.close();

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    saved = await NativeBridge.saveFileAs(zipPath, fileName, 'application/zip');
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    error = e.toString();
  } finally {
    final zip = File(zipPath);
    if (zip.existsSync()) zip.deleteSync();
  }

  if (!context.mounted) return;
  if (error != null) {
    _showMessage(context, "Backup failed", error);
  } else if (saved) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text("Backup saved")));
  }
}

Future<void> restoreLibrary(BuildContext context) async {
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text("Restore from backup?"),
            content: const Text(
                "This replaces all sheets, sets and annotations on this device with the contents of the backup."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Choose Backup...")),
            ],
          ));
  if (confirmed != true) return;

  final picked = await FilePicker.pickFiles(
      type: FileType.custom, allowedExtensions: ['zip']);
  final zipPath = picked.isEmpty ? null : picked.first.path;
  if (zipPath == null || !context.mounted) return;

  final docs = await getApplicationDocumentsDirectory();
  final tmp = await getTemporaryDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final extracted = Directory(join(tmp.path, 'restore_$stamp'));
  final previous = Directory(join(docs.path, '.before_restore_$stamp'));
  final dbPath = await DbManager.instance.databasePath;
  final songsPath = join(docs.path, _songsDirName);

  if (!context.mounted) return;
  _showBusy(context, "Restoring backup...");
  String? error;
  try {
    await extractFileToDisk(zipPath, extracted.path);
    final newDb = File(join(extracted.path, _dbEntryName));
    if (!newDb.existsSync()) {
      throw const FormatException("That file isn't a Sheet Music Viewer backup.");
    }

    // Move the current library aside first so it can be put back if anything fails.
    await DbManager.instance.close();
    previous.createSync(recursive: true);
    _moveIfExists(dbPath, join(previous.path, _dbEntryName));
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('$dbPath$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    _moveIfExists(songsPath, join(previous.path, _songsDirName));
    try {
      newDb.renameSync(dbPath);
      _moveIfExists(join(extracted.path, _songsDirName), songsPath);
    } catch (e) {
      _moveIfExists(join(previous.path, _dbEntryName), dbPath);
      if (Directory(songsPath).existsSync()) Directory(songsPath).deleteSync(recursive: true);
      _moveIfExists(join(previous.path, _songsDirName), songsPath);
      rethrow;
    }
    previous.deleteSync(recursive: true);
  } catch (e) {
    error = e is FormatException ? e.message : e.toString();
  } finally {
    if (extracted.existsSync()) extracted.deleteSync(recursive: true);
    final pickedCopy = File(zipPath);
    if (pickedCopy.existsSync() && pickedCopy.path.startsWith(tmp.path)) pickedCopy.deleteSync();
  }

  imageCache.clear();
  imageCache.clearLiveImages();
  notifyLibraryChanged();

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  if (error != null) {
    _showMessage(context, "Restore failed", error);
  } else {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text("Library restored")));
  }
}

void _moveIfExists(String from, String to) {
  if (FileSystemEntity.isDirectorySync(from)) {
    Directory(from).renameSync(to);
  } else if (File(from).existsSync()) {
    File(from).renameSync(to);
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

void _showBusy(BuildContext context, String message) {
  showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(message)),
              ]),
            ),
          ));
}

void _showMessage(BuildContext context, String title, String message) {
  showDialog(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
            ],
          ));
}
