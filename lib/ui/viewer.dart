import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:native_pdf_view/native_pdf_view.dart';
import 'package:path/path.dart';
import 'package:wakelock/wakelock.dart';

import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:sheet_music_viewer/db_manager.dart';
import 'package:sheet_music_viewer/data/song.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'page_image_editor.dart';

class Viewer extends StatefulWidget {
  final int songId;

//  const Viewer({Key? key, this.songId}) : super(key: key);
  const Viewer(this.songId, {super.key});

  @override
  _ViewerState createState() => _ViewerState();
}

class _ViewerState extends State<Viewer> {
  var db = DbManager.instance;
  bool _showAppBar = true;

  Song? song;
  String songPath = "";
  String songDir = "";

  int? pages = 0;
  int currentPage = 0;
  bool isReady = false;
  bool keyIsDown = false;

  Key photoViewerKey = UniqueKey();

  int keyIdNext = 0;
  int keyIdPrev = 0;

  bool showBottomProgressIndicator = true;
  int showTimerStatus = 2;

  DateTime openTime = DateTime.now();
  Duration? timeOpen;
  Timer? timer;

  bool defaultHideTopNavBar = false;

  //late final PdfController _pdfController;
  late final PageController _pageController;

  //late final PDFDocument document;
  final bool _isLoading = true;

  @override
  void dispose() {
    //print("Disposing pdf controlller..");
    //_pdfController.dispose();
    //print("Calling super.dispose...");
    if (timer != null) {
      timer!.cancel();
    }
    print("Disabling wakelock on close");
    Wakelock.disable();

    super.dispose();
  }

  @override
  void initState() {
    Wakelock.enable();
    getSongAndPath().then((value) {
      setState(() {
        song = value['song'];
        songPath = value['song_path'];
        songDir = value['song_dir'];
        pages = song!.pages;
      });
      //loadDocumentAdvancedPDFViewer();

      /*
      _pdfController = PdfController(
        document: PdfDocument.openFile(songPath),
        initialPage: 0,
      );*/

      _pageController = PageController(initialPage: 0);

      timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        setState(() {
          timeOpen = DateTime.now().difference(openTime);
        });
        if (timeOpen!.inMinutes > 30) {
          Wakelock.disable();
        }
      });
    });
    super.initState();
  }

  Future<Map> getSongAndPath() async {
    Map res = {};
    Song? loadedSong = await db.loadSong(widget.songId);
    res['song'] = loadedSong;
    if (loadedSong != null) {
      res['song_path'] = await loadedSong.path_to_pdf();
      res['song_dir'] = await loadedSong.path_to_dir();
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    int? nextKeyId = prefs.getInt('next');
    if (nextKeyId == null) {
      print("Next key ID was null; setting to default of arrowDown.keyId");
      keyIdNext = LogicalKeyboardKey.arrowDown.keyId;
    } else {
      keyIdNext = (nextKeyId);
      print(
          "Next Key ID was NOT null; setting to stored key ID value of $keyIdNext");
    }

    if (prefs.getInt('prev') == null) {
      print("Key ID for previous key was null; setting to default arrow up");
      keyIdPrev = LogicalKeyboardKey.arrowUp.keyId;
    } else {
      keyIdPrev = prefs.getInt('prev')!;
      print(
          "key ID for previous was NOT null, loaded from settings to: $keyIdPrev");
    }

    if (prefs.getBool('showBottomProgressIndicator') != null) {
      showBottomProgressIndicator =
          prefs.getBool('showBottomProgressIndicator')!;
    }
    if (prefs.getInt('showTimerOnViewer') != null) {
      showTimerStatus = prefs.getInt('showTimerOnViewer')!;
    }

    if (prefs.getBool('hideTopNavBar') != null &&
        prefs.getBool('hideTopNavBar') == true) {
      //Hide the top nav bar by default
      _showAppBar = false;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.bottom]);
    }

    return res;
  }

  Future<void> setTopNavBarPrefs(bool hideTopNavBar) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideTopNavBar', hideTopNavBar);
  }

  void editCurrentPage(BuildContext context) async {

    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (context) => PageImageEditor(image: File(join(songDir, "${currentPage + 1}.jpg")))
    ));

    /*
    imageCache.clear();
    imageCache.clearLiveImages();
    */


    /*await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => MusicList(setId: set.id)) );
    */
    //The 'await' above will block until Navigator.pop is called.
    //widget.onSetUpdated();
    debugPrint("After the above await...");
    setState(() {
      imageCache.clear();
      imageCache.clearLiveImages();

      photoViewerKey = UniqueKey();
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String timestr = "";
    if (duration.inHours > 0) {
      timestr = "${twoDigits(duration.inHours)}:";
    }
    timestr += "$twoDigitMinutes:$twoDigitSeconds";
    if (duration.inHours > 24) {
      timestr = "More than a day";
    }
    return timestr;
  }

  @override
  Widget build(BuildContext context) {
    if (song != null) {
      Widget pageIndicator = Container();
      //print("Page indicator: Pages: ${pages}; current page: ${currentPage}");
      if (showBottomProgressIndicator && pages != null && pages! > 1) {
        pageIndicator = LinearProgressIndicator(
            value: ((currentPage + 1) / pages!),
            color: const Color.fromRGBO(80, 155, 180, 1));
      }

      Widget durationDisplay = Container();
      //print("Time open: ${timeOpen}");
      if (pages != null &&
          timeOpen != null &&
          (showTimerStatus == 1 || //Always show the timer status
              (showTimerStatus == 2 &&
                  pages == (currentPage + 1)) //Show only on the last page
          )) {
        durationDisplay = Text(_formatDuration(timeOpen!));
        //print("Setting duration display: ${durationDisplay}");
      }

      return WillPopScope(
          onWillPop: () async {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);
            return true;
          },
          child: KeyboardListener(
              focusNode: FocusNode(),
              autofocus: true,
              onKeyEvent: (event) {
                //print("Key event (viewer): ${event}");
                if (!keyIsDown) {
                  /* Check to see if we have already processed this key event. If we have, ignore it */
                  print(
                      "Key is pressed! Character: ${event.character}; logical key: ${event.logicalKey.keyId}");
                  print(
                      "Comparing to next key ID: $keyIdNext and previous: $keyIdPrev");
                  //print("Key ID: ${event.logicalKey.keyId}");
                  if (event.logicalKey == LogicalKeyboardKey(keyIdNext)) {
                    print("Going to the next page...");

                    _pageController.nextPage(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeIn);
                  } else if (event.logicalKey ==
                      LogicalKeyboardKey(keyIdPrev)) {
                    print("Going to the previous page...");
                    _pageController.previousPage(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut);
                  }
                }

                if (event is KeyDownEvent) {
                  //print("This is a key down event for ${event.character}");
                  keyIsDown = true;
                } else if (event is KeyUpEvent) {
                  keyIsDown = false;
                  //print("This is a key UP  event for ${event.character}");
                } else if (event is KeyRepeatEvent) {
                  //print("This is a key repeat event; ignore it");
                }
              },
              child: Scaffold(
                  appBar: _showAppBar
                      ? AppBar(
                          title: Text(song!.display_name),
                          leading: const BackButton(),
                          actions: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.edit_note),
                              tooltip: 'Edit Page',
                              onPressed: () {
                                editCurrentPage(context);
                              },
                            ),
                IconButton(
              icon: const Icon(Icons.refresh),
        tooltip: "Refresh",
        onPressed: () {
                debugPrint("Refresh button clicked");
                setState(() {
                  photoViewerKey = UniqueKey();
                  imageCache.clear();
                  imageCache.clearLiveImages();
                });
        })
                          ],
                        )
                      : null,
                  body: GestureDetector(
                      onTap: () {
                        if (_showAppBar) {
                          setState(() {
                            _showAppBar = false;
                          });
                          setTopNavBarPrefs(true);
                          SystemChrome.setEnabledSystemUIMode(
                              SystemUiMode.manual,
                              overlays: [
                                SystemUiOverlay.bottom
                              ]); // to show only bottom bar
                        } else {
                          setState(() {
                            _showAppBar = true;
                          });
                          setTopNavBarPrefs(false);
                          SystemChrome.setEnabledSystemUIMode(
                              SystemUiMode.manual,
                              overlays: [
                                SystemUiOverlay.bottom,
                                SystemUiOverlay.top
                              ]);
                        }
                      },
                      child: Stack(
                        children: [
                          Column(children: [
                            Expanded(
                              key: photoViewerKey,
                                child: PhotoViewGallery.builder(
                              scrollPhysics: const PageScrollPhysics(),
                              builder: (BuildContext context, int index) {
                                return PhotoViewGalleryPageOptions(
                                  filterQuality: FilterQuality.medium,
                                  imageProvider: FileImage(
                                      File(join(songDir, "${index + 1}.jpg"))),
                                  initialScale:
                                      PhotoViewComputedScale.contained * 1,
                                  minScale:
                                      PhotoViewComputedScale.contained * 1,
                                  maxScale: PhotoViewComputedScale.covered * 3,
                                  //heroAttributes: HeroAttributes(tag: galleryItems[index].id),
                                );
                              },
                              itemCount: song!.pages,
                              loadingBuilder: (context, progress) => const Center(
                                child: SizedBox(
                                  width: 20.0,
                                  height: 20.0,
                                  child: CircularProgressIndicator(value: null),
                                ),
                              ),
                              //backgroundDecoration: widget.backgroundDecoration,
                              pageController: _pageController,
                              backgroundDecoration: const BoxDecoration(
                                  color: Color.fromRGBO(255, 255, 255, 1)),
                              onPageChanged: (page) {
                                setState(() {
                                  currentPage = page;
                                });
                              },
                            )),
                            pageIndicator
                          ]),
                          Positioned.fill(
                              bottom: 10,
                              right: 10,
                              child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: durationDisplay))
                        ],
                      )
                      /*PdfView(
                    documentLoader: Center(child: CircularProgressIndicator()),
                    pageLoader: Center(child: CircularProgressIndicator()),
                    controller: _pdfController,
                    renderer: (PdfPage page) => page.render(
                      width: page.width * 3,
                      height: page.height * 3,
                      format: PdfPageFormat.PNG,
                      backgroundColor: '#FFFFFF',
                    ),
                        onDocumentLoaded: (document) {
                      pages = document.pagesCount;
                    },
                    onPageChanged: (page) {
                      currentPage = page;
                    },*/

                      ))));
    } else {
      return const Text("Loading...");
    }

    /*
    return Center(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : PDFViewer(document: document));
    */
  }
}
