import 'package:flutter/material.dart';
import '../data/set.dart';
import 'viewer.dart';
import '../db_manager.dart';
import '../music_list.dart';
import 'set_editor.dart';


class SetListRow extends StatefulWidget {
  final Set initialSet;
  final VoidCallback onSetUpdated;

  const SetListRow({Key? key, required this.initialSet, required this.onSetUpdated}) : super(key: key);

  @override
  _SetListRowState createState() => _SetListRowState();
}

class _SetListRowState extends State<SetListRow> {
  var db = DbManager.instance;
  late Set set;

  Future<void> deleteSet() async {
    var db = DbManager.instance;
    await db.deleteSet(set.id);
    widget.onSetUpdated();
  }

  @override
  void initState() {
    set = widget.initialSet;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return Card(
        child: ListTile(
          //color: Colors.amber[colorCodes[index]],
            title: Text(set.name),
            //subtitle: Text(song.filename.toString()),
            subtitle: Text("${set.numSongs} song${set.numSongs == 1 ? "" : "s"}"),
            trailing: PopupMenuButton(
              child: Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == "edit") {
                  SetEditor se = SetEditor(set: set, onSetChanged: () {
                    print("Calling Set State on the home widget");
                    setState(() {
                      widget.onSetUpdated();
                    });
                  });
                  showDialog(context: context,
                      builder: (BuildContext context) {
                        return se;
                      });
                } else if (value == "delete") {
                  deleteSet();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  child: Text("Choose Songs"),
                  value: "edit",
                ),
                const PopupMenuItem(
                  child: Text("Delete Set"),
                  value: "delete",
                ),
              ],
            ),
            onTap: () async {
              print("In SetList, creating a new MusicList with a set ID of ${set.id}");

              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => MusicList(setId: set.id)) );

              //The 'await' above will block until Navigator.pop is called.
              widget.onSetUpdated();

              //Navigator.push(context, route)

              /*
                        final snackBar = SnackBar(content: Text('Clicked on index $index that has ID ${songdata[index].id}'));
                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                         */
            }));
  }
}
