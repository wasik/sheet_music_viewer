import 'dart:io';
import 'dart:async';
import 'backup.dart';
import 'db_manager.dart';
import 'data/song.dart';
import 'importer.dart';
import 'native_bridge.dart';
import 'ui/settings_footpedal_config_row.dart';

import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  String storage_path = "";
  final List showTimerStrings = ["Never Show", "Always Show", "Show on Last Page"];

  bool showBottomProgressIndicator = true;
  bool hideTopNavBar = true;
  bool twoPageLandscape = true;
  int showTimerStatus = 2;

  String? default_file_import_dir;

  Future<String> _getDirPath() async {
    final dir = await getApplicationDocumentsDirectory();
    storage_path = join(dir.path, "music");
    print("Application documents directory: $dir");

    return dir.path;
  }
  Future<void> _getSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('showBottomProgressIndicator') != null) {
      setState(() {
        showBottomProgressIndicator =
        prefs.getBool('showBottomProgressIndicator')!;
      });
    }
    if (prefs.getInt('showTimerOnViewer') != null) {
      setState(() {
        showTimerStatus = prefs.getInt('showTimerOnViewer')!;
      });
    }
    if (prefs.getBool('hideTopNavBar') != null) {
      setState(() {
        hideTopNavBar = prefs.getBool('hideTopNavBar')!;
      });
    }
    if (prefs.getBool('twoPageLandscape') != null) {
      setState(() {
        twoPageLandscape = prefs.getBool('twoPageLandscape')!;
      });
    }
    if (prefs.getString('default_file_import_dir') != null) {
      setState(() {
        default_file_import_dir = prefs.getString('default_file_import_dir');
      });
    }
  }

  @override
  void initState() {
    _getDirPath();
    _getSettings();

    super.initState();
  }

  void attemptToLoadSong(songid) async {
    /*Song? newsong = await DbManager.instance.loadSong(songid);
    print("New song: ${newsong}");

     */
    List<Song> songs = await DbManager.instance.getSongsForSet(null);
    print("Songs: $songs");
  }

  void _importFiles(BuildContext context) async {
    List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);

    if (result.isNotEmpty) {
      List<String> paths = result.map((f) => f.path).whereType<String>().toList();

      if (paths.isNotEmpty) {
        Directory parentDir = File(paths[0]).parent;
        setState(() {
          default_file_import_dir = parentDir.path;
        });
      }

      if (!context.mounted) return;
      await importPdfFilesWithProgress(context, paths);
    } else {
      if (!context.mounted) return;
      // User canceled the picker
      showDialog(
          context: context,
          builder: (context) => const AlertDialog(
                content: Text("File selection cancelled"),
              ));
    }
  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<String>(
        future: _getDirPath(),
        builder: (context, AsyncSnapshot<String> snapshot) {

          return Column(
                children: [AppBar(
                  title: const Text("Settings"),
                ),
                  Expanded(child:
          ListView(padding: const EdgeInsets.all(20),
            children: <Widget>[
              Text("Import Sheet Music Files",
              style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              Text('Click the button below to choose .pdf files to import. These files must already be on your device (eg. either copied over by a USB cable, or in your Downloads folder). You can also share a PDF to Sheet Music Viewer, or open one with it, from another app.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text("Import Files..."),
                onPressed: () {_importFiles(context);}
              ),

              const Divider(height: 30.0),
              Text("Foot Pedal Configuration",
                style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text('Page Up / Page Down and the arrow keys turn pages by default, which covers most page-turner pedals. Assign keys here if yours sends something else.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),

              const SettingsFootpedalConfigRow(label: "Previous Page", storageKey: 'prev'),
              const SizedBox(height:20),
              const SettingsFootpedalConfigRow(label: "Next Page", storageKey: 'next'),

              const Divider(height: 30.0),
              Text("Configuration",
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),

                 ListTile(title: const Text("Show Timer"),
                   trailing: DropdownButton<int>(
                       value: showTimerStatus,
                       icon: const Icon(Icons.arrow_downward),
                       elevation: 16,
                       style: const TextStyle(color: Colors.deepPurple),
                       underline: Container(
                         height: 2,
                         color: Colors.deepPurpleAccent,
                       ),
                       onChanged: (int? newValue) async {
                         if (newValue != null) {
                           SharedPreferences prefs =
                           await SharedPreferences.getInstance();
                           await prefs.setInt('showTimerOnViewer', newValue);
                           setState(() {
                             showTimerStatus = newValue;
                           });
                         }
                       },
                       items: List.generate(
                           showTimerStrings.length,
                               (index) => DropdownMenuItem<int>(
                               value: index,
                               child: Text(showTimerStrings[index]))
                       )
                   )
          ),


              const SizedBox(height:20),
                    ListTile(title: const Text("Show Progress Indicator"),
                    trailing: Switch(value: showBottomProgressIndicator,
                    onChanged: (bool newValue) async {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      await prefs.setBool('showBottomProgressIndicator', newValue);
                      setState(() {
                        showBottomProgressIndicator = newValue;
                      });
                                        },)),

              const SizedBox(height:20),
              ListTile(title: const Text("Hide Song Title/Nav Bar in Viewer"),
                trailing: Switch(value: hideTopNavBar,
                onChanged: (bool newValue) async {
                  SharedPreferences prefs =
                  await SharedPreferences.getInstance();
                  await prefs.setBool('hideTopNavBar', newValue);
                  setState(() {
                    hideTopNavBar = newValue;
                  });
                })
              ),

              const SizedBox(height:20),
              ListTile(title: const Text("Two Pages Side by Side in Landscape"),
                subtitle: const Text("Tablets only"),
                trailing: Switch(value: twoPageLandscape,
                onChanged: (bool newValue) async {
                  SharedPreferences prefs =
                  await SharedPreferences.getInstance();
                  await prefs.setBool('twoPageLandscape', newValue);
                  setState(() {
                    twoPageLandscape = newValue;
                  });
                })
              ),

              const Divider(height: 30.0),
              Text("Backup",
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text('Save all your sheets, sets and annotations to a single file (e.g. to Google Drive or Downloads), and restore them on this or another device.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text("Back Up Library..."),
                onPressed: () {exportLibrary(context);}
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                child: const Text("Restore from Backup..."),
                onPressed: () {restoreLibrary(context);}
              ),

              const SizedBox(height: 30),
              FutureBuilder<String>(
                future: NativeBridge.getAppVersion(),
                builder: (context, version) => Text(
                  version.hasData ? "Version ${version.data}" : "",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),

                ]
          )
                  ),

          ]);
        });

  }
}
