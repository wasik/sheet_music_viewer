import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:sheet_music_viewer/ui/set_list_navigator.dart';
import 'music_list.dart';

import 'settings_widget.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State createState() {
    return _HomeState();
  }
}

class _HomeState extends State {
  int _currentIndex = 0;

  final GlobalKey<SetListNavigatorState> _setListNavigator = GlobalKey<SetListNavigatorState>();

  late final List _children;

  @override
  void initState() {
    super.initState();
    setupDefaultPreferences();
    _children = [
      MusicList(changeBottomNavTab: onTabTapped,),
      SetListNavigator(key: _setListNavigator),
      const SettingsWidget(),
    ];
  }

  void setupDefaultPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int prefVersion = (prefs.getInt('version') ?? 0);
    if (prefVersion == 0) {
      await prefs.setInt('version', 1);
      await prefs.setInt('next', LogicalKeyboardKey.arrowDown.keyId );
      await prefs.setInt('prev', LogicalKeyboardKey.arrowUp.keyId );
      await prefs.setBool('showBottomProgressIndicator', true);
      await prefs.setInt('showTimerOnViewer', 2);
      await prefs.setBool('hideTopNavBar', false);
    }
  }


  @override
  Widget build(BuildContext context) {

    return WillPopScope(
        onWillPop: () async {
          if (_currentIndex == 1) {
            if (_setListNavigator.currentState!.navStateKey.currentState!.canPop()) {
              _setListNavigator.currentState!.navStateKey.currentState!.maybePop();
              return false;
            } else {
              return true;
            }
          }

          //print("Top level will pop scope called. SEe what tab we're on..");
          return true;
        },
        child:
        Scaffold(
      //appBar: AppBar(
      //  title: Text('Sheet Music Viewer'),
     // ),
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped, // new
        currentIndex: _currentIndex, // new
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'All Sheets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.my_library_music),
            label: 'Sets',
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings'
          )
        ],
      ),
        )
    );
  }
  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
}
