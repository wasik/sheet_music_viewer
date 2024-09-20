import 'package:flutter/material.dart';



class ImporterWidget extends StatelessWidget {

  const ImporterWidget({super.key});

  @override
  Widget build(BuildContext context) {

    return ListView(padding: const EdgeInsets.all(8),
      children: const <Widget>[
        ElevatedButton(
          onPressed: null,
          child: Text("Choose Directory to Import Files"),
        )
      ],
    );

  }
}
