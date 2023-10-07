import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_music_viewer/data/song.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sheet_music_viewer/db_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'mock_path_provider_platform.dart';

Future main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DbManager db;
  late int song1;
  late int song2;
  late int setId;

  Future _initTestData(DbManager db) async {
    Database d = await db.database;
    await d.rawDelete("delete from songs");
    await d.rawDelete("delete from sets");
    await d.rawDelete("delete from setsongs");
    song1 = await db.addSongFromFile("song1.pdf", 33);
    song2 = await db.addSongFromFile("song2.pdf", 22);
  }

  setUpAll(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = DbManager.instance;
  });

  group('Features of version 2', () {
    setUp(() async {
      await _initTestData(db);
    });

    test('keeps the original order of songs in sets', () async {
      Database d = await db.database;
      setId = await db.saveSet(null, [song2, song1], "MySet");
      List<Song> result = await db.getSongsForSet(setId);
      expect(result.map((s) => s.id), equals([song2, song1]));
    });
  });
}
