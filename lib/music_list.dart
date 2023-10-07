import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'db_manager.dart';
import 'data/song.dart';
import 'data/set.dart';
import 'ui/music_list_row.dart';
import 'ui/viewer.dart';

class MusicList extends StatefulWidget {
  final int? setId;
  final void Function(int)? changeBottomNavTab;

  const MusicList({Key? key, this.setId, this.changeBottomNavTab})
      : super(key: key);

  @override
  _MusicListState createState() => _MusicListState();
}

class _MusicListState extends State<MusicList> {
  var db = DbManager.instance;
  List<Song> songs = List.empty();
  Set? currentset = null;

  @override
  void initState() {
    super.initState();
    print("Going to call db.get songs for set with setID ${widget.setId ?? "N/A"}...");
    rebuildSonglist();
  }

  void rebuildSonglist() {
    print("Going to rebuild song list for set ID ${widget.setId ?? "None"}!");

    if (widget.setId != null) {
      db.getSet(widget.setId!).then((retrieved_set) {
        setState(() {
          currentset = retrieved_set;
        });
      });
    }

    db.getSongsForSet(widget.setId).then((songlist) {
      //print("Data returned; going to call setState...");
      setState(() {
        print("Retrieved songs! Song list: ${songlist}");
        songs = songlist;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyWidget;
    if (songs.isEmpty) {
      bodyWidget = const Center(
        child: Text(
          'No sheets found. Import sheets on the Settings tab.',
          style: TextStyle(fontSize: 18),
        ),
      );
    } else {
      bodyWidget = ReorderableListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: songs.length,
        itemBuilder: (BuildContext context, int index) {
          return MusicListRow(
              key: ObjectKey(songs[index]),
              initialSong: songs[index],
              isPartOfListId: widget.setId,
              onSongNameUpdated: rebuildSonglist);
        },
        onReorder: (int oldIndex, int newIndex) {
          setState(() {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final Song song = songs.removeAt(oldIndex);
            songs.insert(newIndex, song);
            if (widget.setId != null && currentset != null) {
              db.saveSet(widget.setId, songs.map((e) => e.id).toList(), currentset!.name);
            }
          });
        },
      );
    }

    Widget floatingActionButton = Container();
    if (currentset == null) {
      floatingActionButton = FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () {
            if (widget.changeBottomNavTab != null) {
              widget.changeBottomNavTab!(2);
            }
          });
    }

    return Column(children: [
      AppBar(
        title: currentset == null
            ? Text("All Sheets")
            : Text("Sheets in ${currentset!.name}"),
      ),
      Expanded(
          child: Stack(
        children: [
          bodyWidget,
          Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: floatingActionButton))
        ],
      ))
    ]);
  }
}
