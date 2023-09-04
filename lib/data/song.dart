import 'dart:io';
import '../db_manager.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class Song {
  int id;
  String filename;
  String display_name;
  int is_single_file;
  String extension;
  int pages;
  Map setIds = {};

  Song({
    required this.id,
    required this.filename,
    required this.display_name,
    required this.is_single_file,
    required this.extension,
    required this.pages
  });

  @override
  String toString() {
    //return 'Song with ID $id and filename $filename';
    return display_name;
  }

  Future<String> path_to_pdf() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'songs', id.toString(), 'song.pdf');
    return path;
  }

  Future<String> path_to_dir() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'songs', id.toString());
    return path;
  }

  Future<void> deleteSongFromDevice() async {
    Directory songStorage = Directory(await path_to_dir());
    songStorage.deleteSync(recursive: true);
    var db = DbManager.instance;
    await db.deleteSong(id);
  }

  Map<String, Object?> toMap() {
    final map = Map<String, dynamic>();
    map['id'] = id;
    map['filename'] = filename;
    map['display_name'] = display_name;
    map['is_single_file'] = is_single_file;
    map['extension'] = extension;
    map['pages'] = pages;
    return map;
  }

   factory Song.fromMap(Map<String, dynamic> res) {
    print("Going to try and return a new Song... with id ${res["id"]}");
     Song thisSong = Song(
         id: res["id"],
         filename: res["filename"],
         display_name: res["display_name"],
         is_single_file: res["is_single_file"],
         extension: res["extension"],
         pages: res["pages"]
     );
     print("This song: ${thisSong}");
     return thisSong;
   }
}
