import 'dart:io';
import 'dart:async';
import 'db_manager.dart';
import 'data/song.dart';
import 'ui/settings_footpedal_config_row.dart';

import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';


class SettingsWidget extends StatefulWidget {
  SettingsWidget() {}

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  String storage_path = "";
  final List showTimerStrings = ["Never Show", "Always Show", "Show on Last Page"];

  bool showBottomProgressIndicator = true;
  bool hideTopNavBar = true;
  int showTimerStatus = 2;

  int numFilesToImport = 0;
  int numFilesImported = 0;

  String? default_file_import_dir = null;

  Future<String> _getDirPath() async {
    final _dir = await getApplicationDocumentsDirectory();
    storage_path = join(_dir.path, "music");
    print("Application documents directory: ${_dir}");

    return _dir.path;
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
    print("Songs: ${songs}");
  }

  /*
  void _importFilesFromDefaultDirectory(BuildContext context) async {
    print("Import files from default directory called. Default directory: ${default_file_import_dir}");

    if (default_file_import_dir != null) {

        Directory defaultDir = Directory(default_file_import_dir!);
        List files = defaultDir.listSync(followLinks: true);

        ProgressDialog pd = ProgressDialog(context: context);
        pd.show(
          max: files.length,
          msg: 'Importing Sheets From Default Location...',
          progressType: ProgressType.valuable,
          //progressBgColor: Colors.transparent,
        );

        int numFilesImported = 0;
        for (var file in files) {
          numFilesImported++;
          print("Possibly try to import file: ${file}");
          pd.update(value: numFilesImported);
        }
    }
  }*/

  Future<void> _importPDFFile(BuildContext context, String filepath) async {
    print("Checking if file exists: ${filepath}");
    bool doesFileExist = await DbManager.instance.doesSongExist(filepath);
    print("Does file exist? ${doesFileExist}");
    try {
      if (doesFileExist == false) {
        final document = await PdfDocument.openFile(filepath);

        int newId = await DbManager.instance
            .addSongFromFile(filepath, document.pagesCount);
        print("New ID from addSongFromFile: ${newId}");
        if (newId > 0) {
          Song? newsong = await DbManager.instance.loadSong(newId);
          if (newsong != null) {
            print("New song: ${newsong}");

            /* Now copy over the file */
            /*
              String pathToSingleFile = await newsong.path_to_pdf();
              File singleFileFile = File(pathToSingleFile);
              singleFileFile.parent.createSync(recursive: true);

              File newfile = file.copySync(pathToSingleFile);
              */

            String pathToSongDir = await newsong.path_to_dir();
            Directory(pathToSongDir).createSync(recursive: true);
            for (var i = 1; i <= document.pagesCount; i++) {
              final page = await document.getPage(i);
              final pageImage = await page.render(
                  width: page.width * 4,
                  height: page.height * 4,
                  quality: 95,
                  format: PdfPageImageFormat.jpeg);

              String page_path = join(pathToSongDir, "${i}.jpg");
              await File(page_path).writeAsBytes(pageImage!.bytes);

              await page.close();
            }
            await document.close();
          } else {
            print("newsong is null; that's not good");
          }
        }
      }
    } catch (e) {}
  }

  void _importFiles(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
    ProgressDialog pd = ProgressDialog(context: context);

    if (result != null) {
      List<File> files = result.paths.where((path) => path != null).map((path) => File(path!)).toList();

      numFilesImported = 0;
      numFilesToImport = result.files.length;

      print("Num files to import: ${numFilesToImport}");
      if (numFilesToImport > 0) {
        print("Going to show PD with max of ${numFilesToImport}");
        pd.show(
          max: numFilesToImport,
          msg: 'Importing Sheets...',
          progressType: ProgressType.valuable,
          //progressBgColor: Colors.transparent,
        );
      }

      if (files.length > 0) {
        Directory parentDir = files[0].parent;
        setState(() {
          default_file_import_dir = parentDir.path;
        });
      }

      for (var file in files) {
        await _importPDFFile(context, file.path);

        numFilesImported++;
        print(
            "Updating the PD spinner with num files: ${numFilesImported}");
        pd.update(value: numFilesImported);

        //file.copySync();
      }
    } else {
      // User canceled the picker
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                content: Text("File selection cancelled"),
              ));
    }
  }

  Future<String?> _chooseImportDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    return selectedDirectory;
  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<String>(
        future: _getDirPath(),
        builder: (context, AsyncSnapshot<String> snapshot) {

          //This was supposed to show a "quick import from last imported directory"
          //But we don't have permission to access that directory
          /*Widget importFromDefaultDirectoryWidget;
          if (default_file_import_dir == null) {
            importFromDefaultDirectoryWidget = Container();
          } else {
            importFromDefaultDirectoryWidget = Column(children:
            [
              SizedBox(height: 20),
              Container(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Quick Import from last Directory:'),
                ),
              ),
              Container(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(default_file_import_dir!),
                ),
              ),
              ListTile(title: Text(""),
                  trailing: ElevatedButton(
                      child: Text("Import All"),
                      onPressed: () {
                        _importFilesFromDefaultDirectory(context);
                      }
                  )
              )
            ]
            );
          }*/

          return Column(
                children: [AppBar(
                  title: Text("Settings"),
                ),
                  Expanded(child:
          ListView(padding: const EdgeInsets.all(20),
            children: <Widget>[
              Text("Import Sheet Music Files",
              style: Theme.of(context).textTheme.headline5),
              SizedBox(height: 20),
              Text('Click the button below to choose .pdf files to import. These files must already be on your device (eg. either copied over by a USB cable, or in your Downloads folder)',
                  style: Theme.of(context).textTheme.bodyText2),
              //Text(snapshot.data.toString()),
              /*ElevatedButton(
                child: Text("Choose Import Directory..."),
                onPressed: _chooseImportDirectory,
              ),*/
              SizedBox(height: 20),
              ElevatedButton(
                child: Text("Import Files..."),
                onPressed: () {_importFiles(context);}
              ),

              new Divider(height: 30.0),
              Text("Foot Pedal Configuration",
                style: Theme.of(context).textTheme.headline5),
              SizedBox(height: 20),

              SettingsFootpedalConfigRow(label: "Previous Page", storageKey: 'prev'),
              SizedBox(height:20),
              SettingsFootpedalConfigRow(label: "Next Page", storageKey: 'next'),

              new Divider(height: 30.0),
              Text("Configuration",
                  style: Theme.of(context).textTheme.headline5),
              SizedBox(height: 20),

                 ListTile(title: Text("Show Timer"),
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


              new SizedBox(height:20),
                    ListTile(title: Text("Show Progress Indicator"),
                    trailing: Switch(value: showBottomProgressIndicator,
                    onChanged: (bool newValue) async {
                      if (newValue != null) {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool('showBottomProgressIndicator', newValue);
                        setState(() {
                          showBottomProgressIndicator = newValue;
                        });
                      }
                    },)),

              new SizedBox(height:20),
              ListTile(title: Text("Hide Song Title/Nav Bar in Viewer"),
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

                ]
          )
                  ),

          ]);
        });

  }
}