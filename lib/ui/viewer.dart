import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' show join;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:sheet_music_viewer/db_manager.dart';
import 'package:sheet_music_viewer/data/annotations.dart';
import 'package:sheet_music_viewer/data/song.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'annotated_page.dart';
import 'page_image_editor.dart';

class Viewer extends StatefulWidget {
  final int songId;

  /// Song IDs of the set this song was opened from, in set order. When given,
  /// turning past the last page continues into the next song of the set.
  final List<int>? setSongIds;

  const Viewer(this.songId, {super.key, this.setSongIds});

  @override
  _ViewerState createState() => _ViewerState();
}

class _ViewerState extends State<Viewer> {
  // Keys most page turners send; these work unless assigned to the opposite action.
  static final _defaultNextKeys = {
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowRight,
  };
  static final _defaultPrevKeys = {
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowLeft,
  };

  var db = DbManager.instance;
  bool _showAppBar = true;

  Song? song;
  String songDir = "";

  /// First page on screen (0-based).
  int currentPage = 0;

  int? nextSongId;
  int? prevSongId;
  String? nextSongName;

  Key photoViewerKey = UniqueKey();
  PageController? _pageController;
  final FocusNode _focusNode = FocusNode();

  int keyIdNext = 0;
  int keyIdPrev = 0;

  bool showBottomProgressIndicator = true;
  int showTimerStatus = 2;
  bool showAnnotations = true;
  bool twoPagePref = true;
  bool twoPageMode = false;

  DateTime openTime = DateTime.now();
  Duration? timeOpen;
  Timer? timer;

  int get pageCount => song?.pages ?? 0;
  int get viewCount => twoPageMode ? (pageCount + 1) ~/ 2 : pageCount;
  int viewIndexFor(int page) => twoPageMode ? page ~/ 2 : page;
  int pageForView(int view) => twoPageMode ? view * 2 : view;
  int get currentView => viewIndexFor(currentPage);
  bool get onLastView => currentView >= viewCount - 1;
  int get lastVisiblePage =>
      twoPageMode ? min(currentPage + 1, pageCount - 1) : currentPage;

  @override
  void dispose() {
    timer?.cancel();
    print("Disabling wakelock on close");
    WakelockPlus.disable();
    _pageController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        timeOpen = DateTime.now().difference(openTime);
      });
      if (timeOpen!.inMinutes > 30) {
        WakelockPlus.disable();
      }
    });
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-evaluated on rotation, since this depends on MediaQuery.
    _updateLayoutMode();
  }

  Future<void> _init() async {
    await _loadPrefs();
    if (!mounted) return;
    setState(_updateLayoutMode);
    await _openSong(widget.songId);
  }

  Future<void> _loadPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    keyIdNext = prefs.getInt('next') ?? LogicalKeyboardKey.arrowDown.keyId;
    keyIdPrev = prefs.getInt('prev') ?? LogicalKeyboardKey.arrowUp.keyId;
    showBottomProgressIndicator = prefs.getBool('showBottomProgressIndicator') ?? true;
    showTimerStatus = prefs.getInt('showTimerOnViewer') ?? 2;
    showAnnotations = prefs.getBool('showAnnotations') ?? true;
    twoPagePref = prefs.getBool('twoPageLandscape') ?? true;

    if (prefs.getBool('hideTopNavBar') == true) {
      //Hide the top nav bar by default
      _showAppBar = false;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.bottom]);
    }
  }

  /// Two pages side by side when a tablet is in landscape. Doesn't call
  /// setState itself, so it can run from didChangeDependencies.
  void _updateLayoutMode() {
    final size = MediaQuery.sizeOf(context);
    final twoUp = twoPagePref && size.width > size.height && size.shortestSide >= 600;
    if (twoUp == twoPageMode) return;
    twoPageMode = twoUp;
    if (song != null) {
      currentPage = pageForView(viewIndexFor(currentPage));
      _resetGallery(currentView);
    }
  }

  /// Rebuilds the gallery (re-reading pages and annotations from disk) at [initialView].
  /// Callers are responsible for triggering a rebuild.
  void _resetGallery(int initialView) {
    final oldController = _pageController;
    // A fresh gallery attaches to the controller at its initialPage, so start
    // the new controller on the page being viewed instead of page 0.
    _pageController = PageController(initialPage: initialView);
    photoViewerKey = UniqueKey();
    // The old gallery is still attached until this frame finishes.
    if (oldController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => oldController.dispose());
    }
  }

  /// Shows song [id], at [startPage] or wherever it was last left off.
  Future<void> _openSong(int id, {int? startPage}) async {
    final loaded = await db.loadSong(id);
    if (loaded == null || !mounted) return;
    final dir = await loaded.path_to_dir();
    int page = startPage ?? await _resumePage(loaded);
    page = page.clamp(0, max(loaded.pages - 1, 0));

    int? next;
    int? prev;
    String? nextName;
    final setIds = widget.setSongIds;
    final index = setIds?.indexOf(id) ?? -1;
    if (setIds != null && index >= 0) {
      if (index + 1 < setIds.length) next = setIds[index + 1];
      if (index > 0) prev = setIds[index - 1];
    }
    if (next != null) nextName = (await db.loadSong(next))?.display_name;
    if (!mounted) return;

    setState(() {
      song = loaded;
      songDir = dir;
      nextSongId = next;
      prevSongId = prev;
      nextSongName = nextName;
      currentPage = pageForView(viewIndexFor(page));
      _resetGallery(currentView);
    });
    db.setLastPage(id, currentPage);
  }

  Future<int> _resumePage(Song s) async {
    final last = await db.getLastPage(s.id);
    // A song that was finished last time starts again from the top.
    final lastView = twoPageMode ? (s.pages - 1) ~/ 2 : s.pages - 1;
    if (lastView > 0 && viewIndexFor(last) >= lastView) return 0;
    return last;
  }

  void _nextPage() {
    final controller = _pageController;
    if (song == null || controller == null) return;
    if (!onLastView) {
      controller.nextPage(
          duration: const Duration(milliseconds: 150), curve: Curves.easeIn);
    } else if (nextSongId != null) {
      _openSong(nextSongId!, startPage: 0);
    }
  }

  void _previousPage() {
    final controller = _pageController;
    if (song == null || controller == null) return;
    if (currentView > 0) {
      controller.previousPage(
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    } else if (prevSongId != null) {
      // Back into the previous song lands on its last page.
      _openSong(prevSongId!, startPage: 1 << 30);
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    print("Key is pressed! Logical key: ${key.keyId}; next: $keyIdNext, previous: $keyIdPrev");
    if (key.keyId == keyIdNext) {
      _nextPage();
    } else if (key.keyId == keyIdPrev) {
      _previousPage();
    } else if (_defaultNextKeys.contains(key)) {
      _nextPage();
    } else if (_defaultPrevKeys.contains(key)) {
      _previousPage();
    }
  }

  /// Left third of the screen goes back, right third goes forward,
  /// the middle shows/hides the title bar.
  void _onTapUp(TapUpDetails details, double width) {
    final x = details.localPosition.dx;
    if (x < width / 3) {
      _previousPage();
    } else if (x > width * 2 / 3) {
      _nextPage();
    } else {
      _toggleAppBar();
    }
  }

  void _toggleAppBar() {
    if (_showAppBar) {
      setState(() {
        _showAppBar = false;
      });
      setTopNavBarPrefs(true);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.bottom]); // to show only bottom bar
    } else {
      setState(() {
        _showAppBar = true;
      });
      setTopNavBarPrefs(false);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);
    }
  }

  Future<void> setTopNavBarPrefs(bool hideTopNavBar) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideTopNavBar', hideTopNavBar);
  }

  Future<void> _toggleAnnotations() async {
    setState(() {
      showAnnotations = !showAnnotations;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showAnnotations', showAnnotations);
  }

  String _pageImagePath(int pageIndex) => join(songDir, "${pageIndex + 1}.jpg");

  Future<void> editPage(int pageIndex) async {
    debugPrint("Edit page $pageIndex; current page = $currentPage");
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
            builder: (context) => PageImageEditor(
                image: File(_pageImagePath(pageIndex)),
                annotationsPath: PageAnnotations.pathFor(songDir, pageIndex))));
    if (saved == true && mounted) {
      // Reload the annotations, staying on the same page.
      setState(() => _resetGallery(currentView));
    }
  }

  void _onPageChanged(int view) {
    debugPrint("onPageChanged called; new view = $view");
    setState(() {
      currentPage = pageForView(view);
    });
    db.setLastPage(song!.id, currentPage);
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

  Widget _page(int pageIndex, Alignment alignment) => AnnotatedPage(
        imagePath: _pageImagePath(pageIndex),
        annotationsPath: PageAnnotations.pathFor(songDir, pageIndex),
        showAnnotations: showAnnotations,
        alignment: alignment,
      );

  PhotoViewGalleryPageOptions _buildView(BuildContext context, int view) {
    Widget child;
    if (twoPageMode) {
      final left = view * 2;
      final right = left + 1;
      child = Row(children: [
        Expanded(child: _page(left, Alignment.centerRight)),
        Expanded(
            child: right < pageCount
                ? _page(right, Alignment.centerLeft)
                : const SizedBox()),
      ]);
    } else {
      child = _page(view, Alignment.center);
    }
    return PhotoViewGalleryPageOptions.customChild(
      child: child,
      initialScale: PhotoViewComputedScale.contained * 1,
      minScale: PhotoViewComputedScale.contained * 1,
      maxScale: PhotoViewComputedScale.contained * 4,
    );
  }

  Widget _editButton() {
    if (twoPageMode && currentPage + 1 < pageCount) {
      return PopupMenuButton<int>(
        icon: const Icon(Icons.edit_note),
        tooltip: 'Edit Page',
        onSelected: editPage,
        itemBuilder: (context) => [
          PopupMenuItem(value: currentPage, child: Text("Left page (${currentPage + 1})")),
          PopupMenuItem(value: currentPage + 1, child: Text("Right page (${currentPage + 2})")),
        ],
      );
    }
    return IconButton(
      icon: const Icon(Icons.edit_note),
      tooltip: 'Edit Page',
      onPressed: () => editPage(currentPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (song == null || _pageController == null) {
      return const Text("Loading...");
    }

    Widget pageIndicator = Container();
    if (showBottomProgressIndicator && pageCount > 1) {
      pageIndicator = LinearProgressIndicator(
          value: ((lastVisiblePage + 1) / pageCount),
          color: const Color.fromRGBO(80, 155, 180, 1));
    }

    Widget durationDisplay = Container();
    if (timeOpen != null &&
        (showTimerStatus == 1 || //Always show the timer status
            (showTimerStatus == 2 && onLastView) //Show only on the last page
        )) {
      durationDisplay = Text(_formatDuration(timeOpen!));
    }

    return PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);
          }
        },
        child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKeyEvent,
            child: Scaffold(
                appBar: _showAppBar
                    ? AppBar(
                        title: Text(song!.display_name),
                        leading: const BackButton(),
                        actions: <Widget>[
                          _editButton(),
                          IconButton(
                            icon: Icon(showAnnotations ? Icons.layers : Icons.layers_clear),
                            tooltip: showAnnotations ? "Hide annotations" : "Show annotations",
                            onPressed: _toggleAnnotations,
                          ),
                          IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: "Refresh",
                              onPressed: () {
                                debugPrint("Refresh button clicked");
                                setState(() {
                                  imageCache.clear();
                                  imageCache.clearLiveImages();
                                  _resetGallery(currentView);
                                });
                              })
                        ],
                      )
                    : null,
                body: LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                        onTapUp: (details) => _onTapUp(details, constraints.maxWidth),
                        child: Stack(
                          children: [
                            Column(children: [
                              Expanded(
                                  key: photoViewerKey,
                                  child: PhotoViewGallery.builder(
                                    scrollPhysics: const PageScrollPhysics(),
                                    builder: _buildView,
                                    itemCount: viewCount,
                                    loadingBuilder: (context, progress) => const Center(
                                      child: SizedBox(
                                        width: 20.0,
                                        height: 20.0,
                                        child: CircularProgressIndicator(value: null),
                                      ),
                                    ),
                                    pageController: _pageController,
                                    backgroundDecoration: const BoxDecoration(
                                        color: Color.fromRGBO(255, 255, 255, 1)),
                                    onPageChanged: _onPageChanged,
                                  )),
                              pageIndicator
                            ]),
                            if (onLastView && nextSongId != null)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 24,
                                child: Center(
                                  child: FilledButton.tonalIcon(
                                    onPressed: _nextPage,
                                    icon: const Icon(Icons.skip_next),
                                    label: Text("Next: ${nextSongName ?? 'next song'}"),
                                  ),
                                ),
                              ),
                            Positioned.fill(
                                bottom: 10,
                                right: 10,
                                child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: durationDisplay))
                          ],
                        ))))));
  }
}
