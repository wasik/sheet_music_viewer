import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart';

enum StrokeTool { pen, highlighter, eraser }

/// One freehand stroke drawn over a page. Stored separately from the page
/// image so annotations can be erased, undone, hidden or cleared later.
///
/// Points are normalized to the page (0..1 in each axis) and [width] is a
/// fraction of the page width, so strokes line up at any display size.
class Stroke {
  final StrokeTool tool;
  final Color color;
  final double width;
  final List<Offset> points;

  Stroke({required this.tool, required this.color, required this.width, List<Offset>? points})
      : points = points ?? [];

  Map<String, dynamic> toJson() => {
        'tool': tool.name,
        'color': color.toARGB32(),
        'width': width,
        'points': [for (final p in points) ...[p.dx, p.dy]],
      };

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final coords = (json['points'] as List).cast<num>();
    return Stroke(
      tool: StrokeTool.values.byName(json['tool'] as String),
      color: Color(json['color'] as int),
      width: (json['width'] as num).toDouble(),
      points: [
        for (var i = 0; i + 1 < coords.length; i += 2)
          Offset(coords[i].toDouble(), coords[i + 1].toDouble())
      ],
    );
  }
}

class PageAnnotations {
  /// Annotations for page [pageIndex] (0-based) of the song stored in [songDir].
  static String pathFor(String songDir, int pageIndex) =>
      join(songDir, 'annotations', '${pageIndex + 1}.json');

  static Future<List<Stroke>> load(String path) async {
    final file = File(path);
    if (!await file.exists()) return [];
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return [
        for (final s in json['strokes'] as List) Stroke.fromJson(s as Map<String, dynamic>)
      ];
    } catch (e) {
      debugPrint("Couldn't read annotations at $path: $e");
      return [];
    }
  }

  static Future<void> save(String path, List<Stroke> strokes) async {
    final file = File(path);
    if (strokes.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'version': 1,
      'strokes': [for (final s in strokes) s.toJson()],
    }));
  }
}

/// Reads an image's pixel size from its header without decoding the whole image.
final Map<String, Size> _imageSizeCache = {};

Future<Size> readImageSize(String path) async {
  final cached = _imageSizeCache[path];
  if (cached != null) return cached;
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final size = Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  descriptor.dispose();
  buffer.dispose();
  return _imageSizeCache[path] = size;
}

/// Paints strokes over a page of the given size.
class AnnotationPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? activeStroke;

  /// Bump to repaint when [strokes] is mutated in place.
  final int revision;

  AnnotationPainter({required this.strokes, this.activeStroke, this.revision = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty && activeStroke == null) return;
    // Paint into a layer so the eraser only clears annotations, not the page.
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      _paintStroke(canvas, size, stroke);
    }
    if (activeStroke != null) _paintStroke(canvas, size, activeStroke!);
    canvas.restore();
  }

  void _paintStroke(Canvas canvas, Size size, Stroke stroke) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.width * size.width
      ..color = stroke.color;
    switch (stroke.tool) {
      case StrokeTool.eraser:
        paint.blendMode = BlendMode.clear;
      case StrokeTool.highlighter:
        paint.strokeCap = StrokeCap.square;
      case StrokeTool.pen:
        break;
    }

    final pts = [for (final p in stroke.points) Offset(p.dx * size.width, p.dy * size.height)];
    if (pts.length == 1) {
      canvas.drawCircle(pts.first, paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }
    // Smooth the line by curving through the midpoints between samples.
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.activeStroke != activeStroke ||
      oldDelegate.revision != revision;
}
