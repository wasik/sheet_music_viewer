import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_painter/image_painter.dart';
import 'package:path_provider/path_provider.dart';

class PageImageEditor extends StatefulWidget {
  final File image;

  const PageImageEditor({super.key, required this.image});

  @override
  State<PageImageEditor> createState() => _PageImageEditorState();
}

class _PageImageEditorState extends State<PageImageEditor> {
  final _key = GlobalKey<ScaffoldState>();
  //final _imageKey = GlobalKey<ImagePainterState>();
  final imagePainterController = ImagePainterController(strokeWidth: 2, color: Colors.blue, mode: PaintMode.freeStyle);


  void saveImage() async {
    //final image = await _imageKey.currentState!.exportImage();
    final image = await imagePainterController.exportImage();
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
          title: const Text("Annotate Page"),
          leading: const BackButton(),
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
        body: ImagePainter.file(widget.image, controller: imagePainterController)
    );
  }
}
