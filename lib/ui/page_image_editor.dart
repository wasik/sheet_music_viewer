import 'dart:io';

import 'package:flutter/material.dart';

import '../data/annotations.dart';

/// Draw on a page. Annotations are saved separately from the page image,
/// so they can be erased, undone or cleared at any time.
///
/// One finger draws; two fingers pinch-zoom and pan.
class PageImageEditor extends StatefulWidget {
  final File image;
  final String annotationsPath;

  const PageImageEditor({super.key, required this.image, required this.annotationsPath});

  @override
  State<PageImageEditor> createState() => _PageImageEditorState();
}

class _PageImageEditorState extends State<PageImageEditor> {
  static const _colors = [Colors.black, Colors.blue, Colors.red, Colors.green];
  // Stroke widths as fractions of the page width.
  static const _sizes = {'Thin': 0.002, 'Medium': 0.004, 'Thick': 0.008};
  static const _highlighterScale = 5.0;
  static const _eraserScale = 6.0;

  Size? _imageSize;
  List<Stroke> _strokes = [];
  final List<List<Stroke>> _undo = [];
  final List<List<Stroke>> _redo = [];
  bool _dirty = false;
  int _revision = 0;

  StrokeTool _tool = StrokeTool.pen;
  Color _color = Colors.blue;
  double _size = _sizes['Medium']!;

  Stroke? _active;

  // Zoom/pan state: content is drawn scaled by _scale and shifted by _offset.
  double _scale = 1;
  Offset _offset = Offset.zero;
  final Map<int, Offset> _pointers = {};
  bool _multiTouch = false;
  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  double _gestureStartDistance = 1;
  Offset _gestureStartFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    Future.wait([
      readImageSize(widget.image.path),
      PageAnnotations.load(widget.annotationsPath),
    ]).then((results) {
      if (!mounted) return;
      setState(() {
        _imageSize = results[0] as Size;
        _strokes = results[1] as List<Stroke>;
      });
    });
  }

  void _commit(List<Stroke> newStrokes) {
    _undo.add(_strokes);
    _redo.clear();
    _strokes = newStrokes;
    _dirty = true;
    _revision++;
  }

  bool get _canUndo => _undo.isNotEmpty || _strokes.isNotEmpty;

  void _undoLast() {
    setState(() {
      _redo.add(_strokes);
      // With no history this session, peel off strokes saved in earlier sessions.
      _strokes = _undo.isNotEmpty ? _undo.removeLast() : _strokes.sublist(0, _strokes.length - 1);
      _dirty = true;
      _revision++;
    });
  }

  void _redoLast() {
    setState(() {
      _undo.add(_strokes);
      _strokes = _redo.removeLast();
      _dirty = true;
      _revision++;
    });
  }

  Future<void> _save() async {
    await PageAnnotations.save(widget.annotationsPath, _strokes);
    _dirty = false;
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Discard changes?"),
              content: const Text("Your changes to this page haven't been saved."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Keep Editing")),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Discard")),
              ],
            ));
    return discard == true;
  }

  Rect _pageRect(Size viewport) {
    final fitted = applyBoxFit(BoxFit.contain, _imageSize!, viewport).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & viewport);
  }

  /// Converts a viewport position into normalized page coordinates.
  Offset _toPage(Offset local, Rect pageRect) {
    final content = (local - _offset) / _scale;
    return Offset((content.dx - pageRect.left) / pageRect.width,
        (content.dy - pageRect.top) / pageRect.height);
  }

  void _onPointerDown(PointerDownEvent e, Rect pageRect) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1 && !_multiTouch) {
      final width = switch (_tool) {
        StrokeTool.pen => _size,
        StrokeTool.highlighter => _size * _highlighterScale,
        StrokeTool.eraser => _size * _eraserScale,
      };
      final color = _tool == StrokeTool.highlighter ? _color.withValues(alpha: 0.35) : _color;
      setState(() {
        _active = Stroke(tool: _tool, color: color, width: width, points: [_toPage(e.localPosition, pageRect)]);
      });
    } else if (_pointers.length >= 2) {
      // A second finger means zoom/pan: drop any stroke the first finger started.
      _multiTouch = true;
      final pts = _pointers.values.take(2).toList();
      _gestureStartDistance = (pts[0] - pts[1]).distance.clamp(1, double.infinity);
      _gestureStartFocal = (pts[0] + pts[1]) / 2;
      _gestureStartScale = _scale;
      _gestureStartOffset = _offset;
      setState(() => _active = null);
    }
  }

  void _onPointerMove(PointerMoveEvent e, Rect pageRect, Size viewport) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_multiTouch && _pointers.length >= 2) {
      final pts = _pointers.values.take(2).toList();
      final focal = (pts[0] + pts[1]) / 2;
      final scale = (_gestureStartScale * (pts[0] - pts[1]).distance / _gestureStartDistance).clamp(1.0, 6.0);
      var offset = focal - (_gestureStartFocal - _gestureStartOffset) * (scale / _gestureStartScale);
      // Keep the viewport filled with content.
      offset = Offset(offset.dx.clamp(viewport.width * (1 - scale), 0),
          offset.dy.clamp(viewport.height * (1 - scale), 0));
      setState(() {
        _scale = scale;
        _offset = offset;
      });
    } else if (_active != null) {
      setState(() {
        _active!.points.add(_toPage(e.localPosition, pageRect));
        _revision++;
      });
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) {
      _multiTouch = false;
      if (_active != null) {
        final stroke = _active!;
        setState(() {
          _active = null;
          _commit([..._strokes, stroke]);
        });
      }
    }
  }

  Widget _toolbar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            SegmentedButton<StrokeTool>(
              segments: const [
                ButtonSegment(value: StrokeTool.pen, icon: Icon(Icons.edit), label: Text("Pen")),
                ButtonSegment(value: StrokeTool.highlighter, icon: Icon(Icons.border_color), label: Text("Highlight")),
                ButtonSegment(value: StrokeTool.eraser, icon: Icon(Icons.auto_fix_normal), label: Text("Eraser")),
              ],
              selected: {_tool},
              onSelectionChanged: (s) => setState(() => _tool = s.first),
            ),
            const SizedBox(width: 16),
            for (final c in _colors)
              GestureDetector(
                onTap: () => setState(() {
                  _color = c;
                  if (_tool == StrokeTool.eraser) _tool = StrokeTool.pen;
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _color == c ? colorScheme.primary : Colors.grey.shade400,
                        width: _color == c ? 3 : 1),
                  ),
                ),
              ),
            const SizedBox(width: 16),
            DropdownButton<double>(
              value: _size,
              underline: const SizedBox(),
              items: [
                for (final entry in _sizes.entries)
                  DropdownMenuItem(value: entry.value, child: Text(entry.key)),
              ],
              onChanged: (v) => setState(() => _size = v!),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Annotate Page"),
          leading: const BackButton(),
          actions: <Widget>[
            IconButton(
                icon: const Icon(Icons.undo),
                tooltip: "Undo",
                onPressed: _canUndo ? _undoLast : null),
            IconButton(
                icon: const Icon(Icons.redo),
                tooltip: "Redo",
                onPressed: _redo.isNotEmpty ? _redoLast : null),
            IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: "Clear all annotations on this page",
                onPressed: _strokes.isEmpty ? null : () => setState(() => _commit([]))),
            IconButton(icon: const Icon(Icons.save), tooltip: "Save", onPressed: _save),
          ],
        ),
        bottomNavigationBar: _toolbar(),
        body: _imageSize == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(builder: (context, constraints) {
                final viewport = constraints.biggest;
                final pageRect = _pageRect(viewport);
                return ClipRect(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _onPointerDown(e, pageRect),
                    onPointerMove: (e) => _onPointerMove(e, pageRect, viewport),
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerUp,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                        ..scaleByDouble(_scale, _scale, 1, 1),
                      child: Stack(children: [
                        Positioned.fromRect(
                          rect: pageRect,
                          child: Stack(fit: StackFit.expand, children: [
                            Image.file(widget.image, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                            CustomPaint(
                              painter: AnnotationPainter(
                                  strokes: _strokes, activeStroke: _active, revision: _revision),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              }),
      ),
    );
  }
}
