import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';



class ImporterWidget extends StatelessWidget {

  ImporterWidget();

  @override
  Widget build(BuildContext context) {

    return ListView(padding: const EdgeInsets.all(8),
      children: <Widget>[
        ElevatedButton(
          child: Text("Choose Directory to Import Files"),
          onPressed: null,
        )
      ],
    );

  }
}
