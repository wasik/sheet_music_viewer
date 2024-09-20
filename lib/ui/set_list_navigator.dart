import 'package:flutter/material.dart';
import 'set_list.dart';

class SetListNavigator extends StatefulWidget {
  const SetListNavigator({super.key});

  @override
  SetListNavigatorState createState() => SetListNavigatorState();
}

class SetListNavigatorState extends State<SetListNavigator> {
  final GlobalKey<SetListState> _setListState = GlobalKey<SetListState>();
  final GlobalKey<NavigatorState> navStateKey = GlobalKey<NavigatorState>();

  void rebuildSetList() {
    print("Going to call to rebuild set list for the displayed SetList...");
    setState(() {
      if (_setListState.currentState != null) {
        print("Calling...");
        _setListState.currentState!.rebuildSetlist();
      }
      //(_children[1] as SetList).lastUpdate = DateTime.now();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navStateKey,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
            settings: settings,
            builder: (BuildContext context) {
              print("Building the SetListNavigator; settings = $settings");
              switch (settings.name) {
                case '/':
                  return SetList(key: _setListState);
                //case '/books2':
                //  return SetList();
                  //return Books2();
              }
              return SetList(key: _setListState);
            });
      },
    );
  }
}
