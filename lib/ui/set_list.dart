import 'package:flutter/material.dart';
import 'set_editor.dart';
import '../data/set.dart';
import '../ui/set_list_row.dart';

import '../db_manager.dart';

class SetList extends StatefulWidget {
  const SetList({super.key});

  @override
  SetListState createState() => SetListState();

  void testFunction() {

  }
}

class SetListState extends State<SetList> {

  var db = DbManager.instance;
  List<Set> sets = List.empty();

  @override
  void initState() {
    super.initState();
    print("Going to call db.get songs for set...");
    rebuildSetlist();
  }

  void rebuildSetlist() {
    print("Going to rebuild song list!");
    db.getSets().then((setlist) {
      setState(() {
        sets = setlist;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyWidget;
    if (sets.isEmpty) {
      bodyWidget = const Center(
        child: Text(
          'No sets found. Create one by clicking the + icon below',
          style: TextStyle(fontSize: 18),
        ),
      );
    } else {
      bodyWidget = ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: sets.length,
          itemBuilder: (BuildContext context, int index) {
            return SetListRow(
                key: ObjectKey(sets[index]),
                initialSet: sets[index],
                onSetUpdated: () {
                  rebuildSetlist();
                });
          });
    }

    return Stack(children: [
      Column(
        children: [AppBar(
          title: const Text("Sets"),
        ),
          Expanded(child: bodyWidget)
        ]
    ), Align(alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () {
              SetEditor se = SetEditor(
                  set: null,
                  onSetChanged: () {
                    print("Calling Set State on the home widget");
                    setState(() {
                      //if (_setListNavigator.currentState != null) {
                     //   _setListNavigator.currentState!.rebuildSetList();
                      //}
                      rebuildSetlist();
                      //(_children[1] as SetList).lastUpdate = DateTime.now();
                    });
                  });
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return se;
                  });
            })
    )
    )
      ]
    );

  }
}
