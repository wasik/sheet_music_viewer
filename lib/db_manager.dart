import 'dart:io';
import 'dart:async';
import 'data/song.dart';
import 'data/set.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DbManager {
  static final _dbName = "sheet_music_viewer.db";

  // Use this class as a singleton
  DbManager._privateConstructor();
  static final DbManager instance = DbManager._privateConstructor();
  static Database? _database;

  Future<Song?> loadSong(int id) async {
    Database db = await instance.database;

    final List<Map<String, Object?>> queryResult = await db.query('songs',
    where: "id=?",
    whereArgs: [id]);

    print("Query result: ${queryResult}");

    if (queryResult.isEmpty) {
      print("Query result is empty");
      return null;
    } else {
      return Song.fromMap(queryResult.first);
    }
  }

  void updateSongDisplayName(int songId, String newDisplayName, Map selectedSetIds) async {
    Database db = await instance.database;

    int updateCount = await db.rawUpdate('''
    update songs set display_name = ? 
    where id = ?
    ''',
        [newDisplayName, songId]
    );

    //Now update the sets that this song is part of...
    await db.rawDelete('delete from setsongs where song_id=?', [songId]);
    for (int setid in selectedSetIds.keys) {
      await db.rawInsert('insert into setsongs (set_id, song_id) values(?, ?)',
          [setid, songId]);
    };

  }

  Future<Set> getSet(int setId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> list;

    list = await db.rawQuery(
        'select sets.* from sets where id=?', [setId]);
    //print("Retrieved sets. List: ${list}");
    //if (list.isNotEmpty) {
      return Set.fromMap(list.first);
    //}
  }

  Future<List<Set>> getSets() async {
    Database db = await instance.database;

    List<Map<String, dynamic>> list;

    list = await db.rawQuery(
        'select sets.*, (select count(*) from setsongs where set_id=sets.id) as numSongs from sets order by sets.name');
    //print("Retrieved sets. List: ${list}");
    List<Set> setlist = list.map((sets) => Set.fromMap(sets)).toList();

    for (int i = 0; i < setlist.length; i++) {
      //print("Getting sets. Going to fetch list of song IDs for set ${setlist[i].id}");
      setlist[i].songIds = await getSetSongIds(setlist[i].id);
    }

    return setlist;
  }


  Future<Map> getSetSongIds(int setId) async {
    Database db = await instance.database;
    Map selIds = {};
    final list = await db.rawQuery('select * from setsongs where set_id=?', [setId]);
    //print("Queried list of set songs... ${list}");
    list.forEach((dbitem) {
      //print("Setting song ID of ${dbitem['song_id']} to true...");
      selIds[dbitem['song_id']] = true;
    });
    return selIds;
  }

  Future<Map> getSongSetIds(int songId) async {
    Database db = await instance.database;
    Map selIds = {};
    final list = await db.rawQuery('select * from setsongs where song_id=?', [songId]);
    //print("Queried list of set songs... ${list}");
    list.forEach((dbitem) {
      //print("Setting song ID of ${dbitem['song_id']} to true...");
      selIds[dbitem['set_id']] = true;
    });
    return selIds;
  }

  Future<List<Song>> getSongsForSet(int? setId) async {
    Database db = await instance.database;

    List<Map<String, dynamic>> list;
print("Called db.getSongsForSet where setId=${setId}");
    if (setId == null) {
      list = await db.rawQuery('select * from songs order by songs.display_name');
    } else {
      list = await db.rawQuery('''select songs.* 
        from songs, setsongs 
        where setsongs.song_id=songs.id 
        and setsongs.set_id=?
        order by setsongs.ordering, songs.display_name
        ''', [setId]);
    }

    List<Song> songs = list.map((songs) => Song.fromMap(songs)).toList();
    for (int i = 0; i < songs.length; i++) {
      //print("Getting sets. Going to fetch list of song IDs for set ${setlist[i].id}");
      songs[i].setIds = await getSongSetIds(songs[i].id);
    }
    return songs;
  }

  Future<int> addSongFromFile(String path, int pages) async {

    Database database = await instance.database;
    print("In DbManager; going to add song with path: ${path}");
    /*return database.insert(
      'songs',
      tvSeries.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
     */

    String display_name = basenameWithoutExtension(path);

    return database.rawInsert('''
    insert into songs (filename, display_name, is_single_file, extension, pages) 
    values(?, ?, ?, ?, ?);
    ''', [basename(path), display_name, 1, extension(path), pages]);
  }

  Future<void> removeSongFromSet(int songId, int setId) async {
    Database database = await instance.database;
    print("Going to remove song ${songId} from set ID ${setId}");
    await database.rawDelete('delete from setsongs where set_id=? and song_id=?', [setId, songId]);
    print("Done removing song.");
  }

  Future<void> deleteSong(int songId) async {
    Database database = await instance.database;
    print("Going to remove song ${songId} from database");
    await database.rawDelete('delete from setsongs where song_id=?', [songId]);
    await database.rawDelete('delete from songs where id=?', [songId]);
  }

  Future<void> deleteSet(int setId) async {
    Database database = await instance.database;
    print("Going to delete set ID ${setId}");
    await database.rawDelete('delete from setsongs where set_id=?', [setId]);
    await database.rawDelete('delete from sets where id=?', [setId]);
    print("Done deleting set ID ${setId}");
  }

  Future<int> saveSet(int? setId, List<int> selectedSongIds, String setName) async {
    Database database = await instance.database;
    int updatedId;

    if (setId == null) {
      updatedId = await database.rawInsert('''
    insert into sets (name) values(?);
    ''', [setName]);
    } else {
      updatedId = setId;
      await database.rawUpdate('''update sets set name=? where id=? ''',
      [setName, setId]);
    }
//print("Added or updated a set with ID: ${updatedId}");
    await database.rawDelete('delete from setsongs where set_id=?', [setId]);
    int ordering = 0;
    for (int songid in selectedSongIds) {
      await database.rawInsert(
          'insert into setsongs (set_id, song_id, ordering) values(?, ?, ?)',
          [updatedId, songid, ordering]);
      ordering += 1;
    }

    return updatedId;
  }

  Future<bool> doesSongExist(String path) async {
    String filename = basename(path);
    Database database = await instance.database;

    int? num_files = Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM songs where filename=?', [filename]));
    if (num_files == null || num_files == 0) {
      return false;
    }
    return true;
  }

  Future<Database> get database async =>
      _database ??= await _initDatabase();

  // Creates and opens the database.
  Future <Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _dbName);
    print("Going to load database from path: ${path}");

    return await openDatabase(
      path,
      version: migrations.length,
      onCreate: (db, version) async {
        print("Creating new database... ${db}");
        _runMigrations(db, 1, version);
        print("Database tables (hopefully) created...");
      },
      onUpgrade: _runMigrations,
    );
  }

  Future _runMigrations(Database db, int oldVersion, newVersion) async {
        var batch = db.batch();
        print("Migrate database $oldVersion -> $newVersion");
        for (var i = oldVersion; i < newVersion; i++) {

          migrations[i](batch);
        }
        await batch.commit();
  }

  var migrations = [
    _initialize1,
    _upgrade2,
  ];

  static void _initialize1(Batch batch) {
    print("Initializing database...");
    batch.execute('''create table songs (
    id integer primary key not null, 
    filename text,
    display_name text,
    pages integer,
    is_single_file integer default 1,
    extension text
    );''');

    batch.execute('''
      create table sets (id integer primary key not null,
      name text);          ''');
    batch.execute('''create table setsongs (song_id int, set_id int);''');
  }

  static void _upgrade2(Batch batch) {
    print("Migration 2");
    batch.execute("alter table setsongs add column ordering;");
  }
}
