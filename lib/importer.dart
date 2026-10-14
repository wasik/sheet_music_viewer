import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:pdfx/pdfx.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';

import 'data/song.dart';
import 'db_manager.dart';
import 'library_events.dart';

enum ImportOutcome { imported, skipped, failed }

/// Imports a PDF into the library, rendering each page to a JPEG.
/// A failed import is rolled back so no half-imported sheet is left behind.
Future<ImportOutcome> importPdfFile(String filepath) async {
  final db = DbManager.instance;
  if (await db.doesSongExist(filepath)) {
    return ImportOutcome.skipped;
  }

  int newId = 0;
  String? songDir;
  PdfDocument? document;
  try {
    document = await PdfDocument.openFile(filepath);
    newId = await db.addSongFromFile(filepath, document.pagesCount);
    Song? newsong = await db.loadSong(newId);
    if (newsong == null) {
      throw StateError("Song $newId wasn't saved");
    }

    songDir = await newsong.path_to_dir();
    Directory(songDir).createSync(recursive: true);
    for (var i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);
      final pageImage = await page.render(
          width: page.width * 4,
          height: page.height * 4,
          quality: 95,
          format: PdfPageImageFormat.jpeg);
      await page.close();
      if (pageImage == null) {
        throw StateError("Page $i couldn't be rendered");
      }
      await File(join(songDir, "$i.jpg")).writeAsBytes(pageImage.bytes);
    }
    return ImportOutcome.imported;
  } catch (e) {
    debugPrint("Import of $filepath failed: $e");
    if (newId > 0) {
      await db.deleteSong(newId);
      if (songDir != null && Directory(songDir).existsSync()) {
        Directory(songDir).deleteSync(recursive: true);
      }
    }
    return ImportOutcome.failed;
  } finally {
    await document?.close();
  }
}

/// Imports [paths] with a progress dialog, then summarizes what happened.
/// [unreadable] are files that never made it to disk (e.g. a share that
/// couldn't be read); they're reported as failures.
Future<void> importPdfFilesWithProgress(BuildContext context, List<String> paths,
    {List<String> unreadable = const []}) async {
  if (paths.isEmpty && unreadable.isEmpty) return;

  final imported = <String>[];
  final skipped = <String>[];
  final failed = <String>[...unreadable];
  final total = paths.length + unreadable.length;

  ProgressDialog pd = ProgressDialog(context: context);
  if (paths.isNotEmpty) {
    pd.show(
      max: paths.length,
      msg: 'Importing Sheets...',
      progressType: ProgressType.determinate,
    );
  }

  for (var i = 0; i < paths.length; i++) {
    final name = basename(paths[i]);
    switch (await importPdfFile(paths[i])) {
      case ImportOutcome.imported:
        imported.add(name);
      case ImportOutcome.skipped:
        skipped.add(name);
      case ImportOutcome.failed:
        failed.add(name);
    }
    pd.update(value: i + 1);
  }
  if (pd.isOpen()) pd.close();

  if (imported.isNotEmpty) notifyLibraryChanged();
  if (!context.mounted) return;

  // A quiet success needs no dialog; anything skipped or failed gets explained.
  if (skipped.isEmpty && failed.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(imported.length == 1
            ? "Imported ${imported.first}"
            : "Imported ${imported.length} sheets")));
    return;
  }

  await showDialog(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text("Import finished"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Imported ${imported.length} of $total files."),
                  if (failed.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text("Couldn't be imported (not a readable PDF?):",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final name in failed) Text("• $name"),
                  ],
                  if (skipped.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text("Already in your library (skipped):",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final name in skipped) Text("• $name"),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context), child: const Text("OK"))
            ],
          ));
}
