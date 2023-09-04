import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_painter/image_painter.dart';
import 'package:path_provider/path_provider.dart';

class PageImageEditor extends StatefulWidget {
  final File image;

  const PageImageEditor({Key? key, required this.image}) : super(key: key);

  @override
  State<PageImageEditor> createState() => _PageImageEditorState();
}

class _PageImageEditorState extends State<PageImageEditor> {
  final _key = GlobalKey<ScaffoldState>();
  final _imageKey = GlobalKey<ImagePainterState>();

  void saveImage() async {
    final image = await _imageKey.currentState!.exportImage();
    final directory = (await getApplicationDocumentsDirectory()).path;
    await Directory('$directory/sample').create(recursive: true);
    final imgFile = widget.image;
    imgFile.writeAsBytesSync(image!.toList());
    Navigator.of(context).maybePop();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _key,
        appBar: AppBar(
          title: Text("Annotate Page"),
          leading: BackButton(),
          actions: <Widget>[
            /*IconButton(
                icon: const Icon(Icons.cancel),
                tooltip: 'Cancel',
                onPressed: () {}),*/
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: "Save",
              onPressed: () { saveImage();
              }
            )
          ],
        ),
        body: ImagePainter.file(widget.image,
            key: _imageKey,
            scalable: true,
            initialStrokeWidth: 2.0,
            initialColor: Colors.blue,
            brushIcon: null,
            initialPaintMode: PaintMode.freeStyle));
  }
}
