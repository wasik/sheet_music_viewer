import '../db_manager.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class Set {
  int id;
  String name;
  int numSongs = 0;
  Map songIds = {};

  Set({
    required this.id,
    required this.name
  });

  @override
  String toString() {
    //return 'Song with ID $id and filename $filename';
    return name;
  }

  Map<String, Object?> toMap() {
    final map = Map<String, dynamic>();
    map['id'] = id;
    map['name'] = name;
    return map;
  }

  /*
  Future<int> numSongs() async {
    var db = DbManager.instance;

    Map songids = await db.getSetSongIds(id);
    return songids.keys.length;
  }

   */

  factory Set.fromMap(Map<String, dynamic> res) {
    print("Going to try and return a new Song... with id ${res["id"]}");
    Set thisSet = Set(
        id: res["id"],
        name: res["name"],
    );
    if (res.containsKey("numSongs")) {
      thisSet.numSongs = res["numSongs"];
    }
    print("This set: ${thisSet}");
    return thisSet;
  }

}
