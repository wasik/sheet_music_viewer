import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/song.dart';

import 'package:sheet_music_viewer/db_manager.dart';
import 'package:sheet_music_viewer/data/set.dart';


class SetEditor extends StatefulWidget {
  final Set? set;
  final VoidCallback onSetChanged;

  const SetEditor({Key? key, required this.set, required this.onSetChanged}) : super(key: key);

  @override
  _SetEditorState createState() => _SetEditorState();
}



class _SetEditorState extends State<SetEditor> {
  final _formKey = GlobalKey<FormState>();

  var db = DbManager.instance;
  List<Song> songs = List.empty();

  TextEditingController _changeSetNameController = TextEditingController();

  Map checkedIds = {};


  @override
  void initState() {
    super.initState();
    if (widget.set != null) {
      _changeSetNameController.text = widget.set!.name;
      checkedIds = widget.set!.songIds;
    }
    rebuildSonglist();
  }

  void rebuildSonglist() {
    print("Going to rebuild song list!");
    db.getSongsForSet(null).then((songlist) {
      print("Data returned; going to call setState...");
      setState(() {
        print("Retrieved songs! Song list: ${songlist}");
        songs = songlist;
      });
    });
  }

  Future<void> saveSet(String newName) async {
    var db = DbManager.instance;
    print("Going to save a set with the name ${newName} and checked IDs: ${checkedIds}");

    await db.saveSet(
        widget.set == null ? null : widget.set!.id,
        checkedIds.keys.map((k) => k as int).toList(),
      newName
    );
    widget.onSetChanged();
  }

  @override
  Widget build(BuildContext context) {

    String dialogTitle = "Create New Set";
    if (widget.set != null) {
      dialogTitle = "Edit Set";
    }

    Widget songSelector;
    if (songs.isEmpty) {
      songSelector = Text("(No songs found; import songs on the Settings tab)");
    } else {
      songSelector = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: ListView.builder(
            shrinkWrap: true,
            itemCount: songs.length,
            itemBuilder: (BuildContext context, int index) {
              int songIdAtIndex = songs[index].id;
              return CheckboxListTile(
                  title: Text(songs[index].display_name),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: checkedIds.containsKey(songIdAtIndex) ? true : false,
                  onChanged: (value) {
                    setState(() {
                      if (checkedIds.containsKey(songIdAtIndex)) {
                        checkedIds.remove(songIdAtIndex);
                      } else {
                        checkedIds[songIdAtIndex] = true;
                      }
                    });
                  });
            }),
      );
    }

    return AlertDialog(
      title: Text(dialogTitle),
      content: SingleChildScrollView(
        child: Container(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                autofocus: false,
                maxLines: 1,
                controller: _changeSetNameController,
                style: TextStyle(fontSize: 18),
                validator:(value) {
                  if (value == null || value.isEmpty) {
                    return 'Set Name is required';
                  }
                  if (value.length > 50) {
                    return 'Set name is too long';
                  }
                  return null;
                },
                decoration: new InputDecoration(
                  border: InputBorder.none,
                  labelText: "Set Name",
                ),
              ),
              SizedBox(height:40),
              Align(alignment: Alignment.centerLeft,
                  child: Text("Songs", style: TextStyle(fontSize:20, fontWeight: FontWeight.w400),)
              ),

              songSelector

            ],
          ),
        ),
      ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () {
            setState(() {
              Navigator.pop(context);
            });
          },
        ),
        ElevatedButton(
          child: Text('Save'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              saveSet(_changeSetNameController.text);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
