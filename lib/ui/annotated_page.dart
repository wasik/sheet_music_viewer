import 'dart:io';

import 'package:flutter/material.dart';

import '../data/annotations.dart';

/// A page image with its saved annotations drawn on top.
class AnnotatedPage extends StatefulWidget {
  final String imagePath;
  final String annotationsPath;
  final bool showAnnotations;

  /// Where the page sits in the available space (e.g. pushed together in two-page view).
  final Alignment alignment;

  const AnnotatedPage({
    super.key,
    required this.imagePath,
    required this.annotationsPath,
    this.showAnnotations = true,
    this.alignment = Alignment.center,
  });

  @override
  State<AnnotatedPage> createState() => _AnnotatedPageState();
}

class _AnnotatedPageState extends State<AnnotatedPage> {
  Size? _imageSize;
  List<Stroke> _strokes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AnnotatedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.annotationsPath != widget.annotationsPath) {
      _load();
    }
  }

  Future<void> _load() async {
    final size = await readImageSize(widget.imagePath);
    final strokes = await PageAnnotations.load(widget.annotationsPath);
    if (!mounted) return;
    setState(() {
      _imageSize = size;
      _strokes = strokes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.file(File(widget.imagePath),
        fit: _imageSize == null ? BoxFit.contain : BoxFit.fill,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true);
    if (_imageSize == null) return image;

    return Align(
      alignment: widget.alignment,
      child: AspectRatio(
        aspectRatio: _imageSize!.width / _imageSize!.height,
        child: Stack(fit: StackFit.expand, children: [
          image,
          if (widget.showAnnotations && _strokes.isNotEmpty)
            CustomPaint(painter: AnnotationPainter(strokes: _strokes)),
        ]),
      ),
    );
  }
}
