import 'package:flutter/material.dart';
import 'package:sheet_music_viewer/data/set.dart';
import '../data/song.dart';
import 'viewer.dart';
import '../db_manager.dart';


class MusicListRow extends StatefulWidget {
  final Song initialSong;
  final int? isPartOfListId;
  final VoidCallback onSongNameUpdated;

  const MusicListRow({super.key, required this.initialSong, required this.isPartOfListId, required this.onSongNameUpdated});

  @override
  _MusicListRowState createState() => _MusicListRowState();
}

class _MusicListRowState extends State<MusicListRow> {
  var db = DbManager.instance;
  late Song song;
  Map checkedIds = {};
  List<Set> sets = List.empty();

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _changeSongDisplayNameController = TextEditingController();

  /*
  void updateSong() async {
    Song? loaded_song = await db.loadSong(song.id);
    if (loaded_song != null) {
      setState(() {
        song = loaded_song;
      });
    }
  }

   */

  Future<void> updateSongDisplayName(int songId, String newName) async {
    var db = DbManager.instance;
    db.updateSongDisplayName(songId, newName, checkedIds);
  }

  @override
  void initState() {
    song = widget.initialSong;
    _changeSongDisplayNameController.text = song.display_name;
    checkedIds = song.setIds;
    rebuildSetList();
    super.initState();
  }

  Future<void> removeSongFromSet(int songId, int setId) async {
    var db = DbManager.instance;
    await db.removeSongFromSet(songId, setId);
    widget.onSongNameUpdated();
  }
  Future<void> deleteSong() async {
    print("Going to delete song from device... ${song.id}");
    await song.deleteSongFromDevice();
    widget.onSongNameUpdated();
  }

  void rebuildSetList() {
    db.getSets().then((setlist) {
      setState(() {
        sets = setlist;
      });
    });
  }

  Future<void> _showConfirmRemoveSong(BuildContext context, bool permanentlyDelete) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Rename Song'),
            content: permanentlyDelete ? const Text("Are you sure you want to remove this sheet from this app and any sets it belongs to?") : const Text("Are you sure you want to remove this sheet from this set?"),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  setState(() {
                    Navigator.pop(context);
                  });
                },
              ),
              TextButton(
                child: const Text('Remove'),
                onPressed: () {
                  if (permanentlyDelete) {
                    //If this is the "All Sheets" page and we want to permanently delete this widget...
                    deleteSong();
                    setState(() {
                      Navigator.pop(context);
                    });
                  } else {
                    removeSongFromSet(song.id, widget.isPartOfListId!);
                    setState(() {
                      Navigator.pop(context);
                    });
                  }
                },
              ),
            ],
          );
        });

  }

  Future<void> _displayEditSongDialog(BuildContext context) async {

    Widget setSelector = Container();
    if (sets.isEmpty) {
      setSelector = const Text("(No sets found; create a set on the Sets tab)");
    } else {
      setSelector = Container();
    }

    await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            //title: Text('Rename Song'),
            content: StatefulBuilder(
              builder:(BuildContext context, StateSetter setState)
          {
            return SingleChildScrollView(child:
            SizedBox(
                width: double.maxFinite,
                child: Form(
                    key: _formKey,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Align(alignment: Alignment.centerLeft,
                              child: Text("Song Name", style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400),
                              )),
                          TextFormField(
                            onChanged: (value) {},
                            controller: _changeSongDisplayNameController,
                            decoration: const InputDecoration(
                                hintText: "Song Display Name"),
                          ),
                          const SizedBox(height: 5),
                          Align(alignment: Alignment.centerLeft, child:
                          Text(song.filename, style: const TextStyle(fontSize: 14))
                          ),
                          const SizedBox(height: 40),
                          const Align(alignment: Alignment.centerLeft,
                              child: Text("Sets", style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400),
                                )),
                            if (sets.isEmpty)
                              const Text("No sets - create a new set on the Sets tab")
                            else
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.4,
                                ),
                                child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: sets.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      int setIdAtIndex = sets[index].id;
                                      return CheckboxListTile(
                                          title: Text(sets[index].name),
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          value: checkedIds
                                                  .containsKey(setIdAtIndex)
                                              ? true
                                              : false,
                                          onChanged: (value) {
                                            print(
                                                "Song ID: ${song.id}; set ID: $setIdAtIndex was tapped");
                                            setState(() {
                                              if (checkedIds
                                                  .containsKey(setIdAtIndex)) {
                                                checkedIds.remove(setIdAtIndex);
                                              } else {
                                                checkedIds[setIdAtIndex] = true;
                                              }
                                            });
                                          });
                                    }),
                              )
                          ])
                )
            )
            );
          }
          )
          ,
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  setState(() {
                    Navigator.pop(context);
                  });
                },
              ),
              ElevatedButton(
                child: const Text('Save'),
                onPressed: () {
                  String newSongName = _changeSongDisplayNameController.text;
                  if (newSongName.trim().isEmpty) {
                    newSongName = song.filename;
                  }
                  updateSongDisplayName(song.id, newSongName).then((value) {
                    widget.onSongNameUpdated();
                    setState(() {
                      Navigator.pop(context);
                    });
                  });
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {

    PopupMenuItem deleteMenuItem;
    if (widget.isPartOfListId == null) {
      deleteMenuItem = const PopupMenuItem(
        value: "delete",
        child: Text("Delete from App"),
      );
    } else {
      deleteMenuItem = const PopupMenuItem(
        value: "remove",
        child: Text("Remove from Set"),
      );
    }



    return Card(
        child: ListTile(
            //color: Colors.amber[colorCodes[index]],
            title: Text(song.toString(), style: TextStyle(
              fontSize: 18,
            )
            ),
            subtitle: Text("${song.pages} pages "),
            //trailing: Icon(Icons.more_vert),
            trailing: PopupMenuButton(
              child: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == "edit") {
                  _displayEditSongDialog(context);
                } else if (value == "delete") {
                  _showConfirmRemoveSong(context, true);
                } else if (value == "remove") {
                  _showConfirmRemoveSong(context, false);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: "edit",
                  child: Text("Edit Name / Sets"),
                ),

                deleteMenuItem
              ],
            ),
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (context) => Viewer(song.id)));
              /*
                        final snackBar = SnackBar(content: Text('Clicked on index $index that has ID ${songdata[index].id}'));
                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                         */
            }));
  }
}
